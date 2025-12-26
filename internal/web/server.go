package web

import (
	"database/sql"
	"embed"
	"fmt"
	"html/template"
	"io/fs"
	"net/http"
	"strconv"
	"time"

	"scallop/internal/config"
	"scallop/internal/database"

	"github.com/gin-gonic/gin"
)

//go:embed templates/*
var TemplatesFS embed.FS

//go:embed static/*
var StaticFS embed.FS

// Server Web服务器
type Server struct {
	db            *database.DB
	configManager *config.Manager
}

// NewServer 创建Web服务器
func NewServer(db *database.DB, configManager *config.Manager) *Server {
	return &Server{
		db:            db,
		configManager: configManager,
	}
}

// Start 启动Web服务器
func (s *Server) Start() error {
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// 设置嵌入的静态文件系统
	staticSubFS, err := fs.Sub(StaticFS, "static")
	if err != nil {
		return fmt.Errorf("无法创建静态文件子系统: %v", err)
	}
	r.StaticFS("/static", http.FS(staticSubFS))

	// 设置嵌入的模板文件系统
	templatesSubFS, err := fs.Sub(TemplatesFS, "templates")
	if err != nil {
		return fmt.Errorf("无法创建模板文件子系统: %v", err)
	}

	// 解析嵌入的模板
	tmpl := template.Must(template.New("").ParseFS(templatesSubFS, "*.html"))
	r.SetHTMLTemplate(tmpl)

	// 注册路由
	s.registerRoutes(r)

	config := s.configManager.Get()
	fmt.Printf("Web服务器启动在 http://localhost:%d\n", config.WebPort)
	return r.Run(fmt.Sprintf(":%d", config.WebPort))
}

// registerRoutes 注册路由
func (s *Server) registerRoutes(r *gin.Engine) {
	// 主页
	r.GET("/", s.handleIndex)

	// PWA manifest
	r.GET("/manifest.json", s.handleManifest)

	// API路由
	api := r.Group("/api")
	{
		api.GET("/ping-data", s.handlePingData)
		api.GET("/targets", s.handleTargets)
		api.GET("/config", s.handleConfig)
		api.GET("/status", s.handleStatus)
	}
}

// handleIndex 主页处理
func (s *Server) handleIndex(c *gin.Context) {
	targets := s.db.GetTargets()
	var displayTargets []map[string]interface{}

	for _, target := range targets {
		displayAddr := target.Addr
		if target.HideAddr {
			displayAddr = ""
		}

		displayTargets = append(displayTargets, map[string]interface{}{
			"id":          target.ID,
			"addr":        displayAddr,
			"description": target.Description,
			"hide_addr":   target.HideAddr,
		})
	}

	c.HTML(http.StatusOK, "index.html", gin.H{
		"targets": displayTargets,
	})
}

// handlePingData 获取ping数据
func (s *Server) handlePingData(c *gin.Context) {
	targetID := c.Query("target_id")
	addr := c.Query("addr") // 兼容旧API
	hours := c.Query("hours")
	startTime := c.Query("start_time")
	endTime := c.Query("end_time")

	var since, until time.Time
	var err error

	// 优先使用自定义时间范围
	if startTime != "" && endTime != "" {
		since, err = time.Parse(time.RFC3339, startTime)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "开始时间格式错误"})
			return
		}
		until, err = time.Parse(time.RFC3339, endTime)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "结束时间格式错误"})
			return
		}
		if since.After(until) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "开始时间不能晚于结束时间"})
			return
		}
	} else {
		// 使用小时数
		h := 1
		if hours != "" {
			h, _ = strconv.Atoi(hours)
		}
		since = time.Now().Add(-time.Duration(h) * time.Hour)
		until = time.Now()
	}

	var query string
	var args []interface{}

	if targetID != "" {
		query = `SELECT pr.target_id, t.addr, t.description, t.hide_addr, pr.latency, pr.success, pr.timestamp 
				 FROM ping_results pr 
				 JOIN targets t ON pr.target_id = t.id 
				 WHERE pr.target_id = ? AND pr.timestamp >= ? AND pr.timestamp <= ? 
				 ORDER BY pr.timestamp ASC`
		args = []interface{}{targetID, since, until}
	} else if addr != "" {
		query = `SELECT pr.target_id, t.addr, t.description, t.hide_addr, pr.latency, pr.success, pr.timestamp 
				 FROM ping_results pr 
				 JOIN targets t ON pr.target_id = t.id 
				 WHERE t.addr = ? AND pr.timestamp >= ? AND pr.timestamp <= ? 
				 ORDER BY pr.timestamp ASC`
		args = []interface{}{addr, since, until}
	} else {
		c.JSON(http.StatusBadRequest, gin.H{"error": "需要提供target_id或addr参数"})
		return
	}

	rows, err := s.db.GetConn().Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	results := s.scanPingResults(rows)
	c.JSON(http.StatusOK, results)
}

// handleTargets 获取所有目标
func (s *Server) handleTargets(c *gin.Context) {
	targets := s.db.GetTargets()
	var displayTargets []map[string]interface{}

	for _, target := range targets {
		displayAddr := target.Addr
		if target.HideAddr {
			displayAddr = ""
		}

		displayTargets = append(displayTargets, map[string]interface{}{
			"id":          target.ID,
			"addr":        displayAddr,
			"description": target.Description,
			"hide_addr":   target.HideAddr,
		})
	}
	c.JSON(http.StatusOK, displayTargets)
}

// handleConfig 获取配置信息
func (s *Server) handleConfig(c *gin.Context) {
	config := s.configManager.Get()
	targets := s.db.GetTargets()

	c.JSON(http.StatusOK, gin.H{
		"title":         config.Title,
		"description":   config.Description,
		"ping_interval": config.PingInterval,
		"ping_count":    config.PingCount,
		"web_port":      config.WebPort,
		"default_dns":   config.DefaultDNS,
		"targets_count": len(targets),
	})
}

// handleStatus 获取最新状态
func (s *Server) handleStatus(c *gin.Context) {
	query := `SELECT pr.target_id, t.addr, t.description, t.hide_addr, pr.latency, pr.success, pr.timestamp 
			  FROM ping_results pr 
			  JOIN targets t ON pr.target_id = t.id 
			  WHERE (pr.target_id, pr.timestamp) IN (
				  SELECT target_id, MAX(timestamp) 
				  FROM ping_results 
				  GROUP BY target_id
			  )`

	rows, err := s.db.GetConn().Query(query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	results := s.scanPingResults(rows)
	c.JSON(http.StatusOK, results)
}

// handleManifest 处理 PWA manifest.json
func (s *Server) handleManifest(c *gin.Context) {
	config := s.configManager.Get()
	
	title := config.Title
	if title == "" {
		title = "Scallop - 网络延迟监控"
	}
	
	description := config.Description
	if description == "" {
		description = "实时监控网络延迟和连接状态"
	}
	
	manifest := map[string]interface{}{
		"name":             title,
		"short_name":       "Scallop",
		"description":      description,
		"start_url":        "/",
		"display":          "standalone",
		"background_color": "#667eea",
		"theme_color":      "#667eea",
		"orientation":      "portrait-primary",
		"icons": []map[string]interface{}{
			{
				"src":     "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='0.9em' font-size='90'>🐚</text></svg>",
				"sizes":   "192x192",
				"type":    "image/svg+xml",
				"purpose": "any maskable",
			},
			{
				"src":     "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='0.9em' font-size='90'>🐚</text></svg>",
				"sizes":   "512x512",
				"type":    "image/svg+xml",
				"purpose": "any maskable",
			},
		},
		"categories":  []string{"utilities", "productivity"},
		"screenshots": []interface{}{},
	}
	
	c.JSON(http.StatusOK, manifest)
}

// scanPingResults 扫描ping结果
func (s *Server) scanPingResults(rows *sql.Rows) []map[string]interface{} {
	var results []map[string]interface{}

	for rows.Next() {
		var targetID, addr, description string
		var hideAddr bool
		var latency float64
		var success bool
		var timestamp time.Time

		err := rows.Scan(&targetID, &addr, &description, &hideAddr, &latency, &success, &timestamp)
		if err != nil {
			continue
		}

		displayAddr := addr
		if hideAddr {
			displayAddr = ""
		}

		results = append(results, map[string]interface{}{
			"target_id":   targetID,
			"addr":        displayAddr,
			"description": description,
			"latency":     latency,
			"success":     success,
			"timestamp":   timestamp,
			"hide_addr":   hideAddr,
		})
	}

	return results
}
