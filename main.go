package main

import (
	"database/sql"
	"embed"
	"encoding/json"
	"fmt"
	"html/template"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	_ "modernc.org/sqlite"
)

//go:embed templates/*
var templatesFS embed.FS

//go:embed static/*
var staticFS embed.FS

type IPTarget struct {
	Addr        string `json:"addr"`
	Description string `json:"description"`
}

type Config struct {
	Targets      []IPTarget `json:"targets"`
	PingInterval int        `json:"ping_interval"` // ping间隔，单位：秒
	WebPort      int        `json:"web_port"`      // Web服务端口
}

type PingResult struct {
	ID          int       `json:"id"`
	Addr        string    `json:"addr"`
	Description string    `json:"description"`
	Latency     float64   `json:"latency"` // 毫秒
	Success     bool      `json:"success"`
	Timestamp   time.Time `json:"timestamp"`
}

type PingMonitor struct {
	db      *sql.DB
	config  Config
	dbMutex sync.Mutex
}

func main() {
	monitor := &PingMonitor{}
	
	fmt.Println("正在启动Ping监控器...")
	
	// 初始化数据库
	fmt.Println("初始化数据库...")
	if err := monitor.initDB(); err != nil {
		log.Fatal("初始化数据库失败:", err)
	}
	defer monitor.db.Close()

	// 加载配置
	fmt.Println("加载配置文件...")
	if err := monitor.loadConfig(); err != nil {
		log.Fatal("加载配置失败:", err)
	}
	
	fmt.Printf("已加载 %d 个监控目标\n", len(monitor.config.Targets))
	for _, target := range monitor.config.Targets {
		fmt.Printf("- %s (%s)\n", target.Description, target.Addr)
	}
	fmt.Printf("Ping间隔: %d秒\n", monitor.config.PingInterval)
	fmt.Printf("Web端口: %d\n", monitor.config.WebPort)

	// 启动ping监控
	fmt.Println("启动ping监控...")
	go monitor.startPingLoop()

	// 启动Web服务器
	fmt.Println("启动Web服务器...")
	monitor.startWebServer()
}

func (pm *PingMonitor) initDB() error {
	var err error
	pm.db, err = sql.Open("sqlite", "./ping_data.db")
	if err != nil {
		return err
	}

	// 创建表
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS ping_results (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		addr TEXT NOT NULL,
		description TEXT NOT NULL,
		latency REAL NOT NULL,
		success BOOLEAN NOT NULL,
		timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_addr_timestamp ON ping_results(addr, timestamp);
	`
	
	_, err = pm.db.Exec(createTableSQL)
	return err
}

func (pm *PingMonitor) loadConfig() error {
	// 检查配置文件是否存在
	if _, err := os.Stat("config.json"); os.IsNotExist(err) {
		// 创建默认配置
		defaultConfig := Config{
			Targets: []IPTarget{
				{Addr: "8.8.8.8", Description: "Google DNS"},
				{Addr: "114.114.114.114", Description: "114 DNS"},
				{Addr: "1.1.1.1", Description: "Cloudflare DNS"},
				{Addr: "223.5.5.5", Description: "阿里 DNS"},
			},
			PingInterval: 10, // 默认10秒
			WebPort:      8081, // 默认端口8081
		}
		
		data, _ := json.MarshalIndent(defaultConfig, "", "  ")
		if err := os.WriteFile("config.json", data, 0644); err != nil {
			return err
		}
		pm.config = defaultConfig
		return nil
	}

	// 读取配置文件
	data, err := os.ReadFile("config.json")
	if err != nil {
		return err
	}

	// 尝试解析新格式的配置
	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		// 如果解析失败，尝试解析旧格式（只有targets数组）
		var targets []IPTarget
		if err := json.Unmarshal(data, &targets); err != nil {
			return err
		}
		// 转换为新格式
		config = Config{
			Targets:      targets,
			PingInterval: 10,   // 默认10秒
			WebPort:      8081, // 默认端口8081
		}
		// 保存新格式的配置
		data, _ := json.MarshalIndent(config, "", "  ")
		os.WriteFile("config.json", data, 0644)
	}

	// 验证配置值
	if config.PingInterval <= 0 {
		config.PingInterval = 10
	}
	if config.WebPort <= 0 || config.WebPort > 65535 {
		config.WebPort = 8081
	}

	pm.config = config
	return nil
}

func (pm *PingMonitor) ping(addr string) (float64, bool) {
	start := time.Now()
	
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		// Windows ping命令
		cmd = exec.Command("ping", "-n", "1", "-w", "3000", addr)
	} else {
		// Linux/Mac ping命令
		cmd = exec.Command("ping", "-c", "1", "-W", "3", addr)
	}
	
	output, err := cmd.Output()
	if err != nil {
		return 0, false
	}
	
	duration := time.Since(start)
	
	// 解析ping输出获取延迟
	latency := pm.parsePingOutput(string(output))
	if latency > 0 {
		return latency, true
	}
	
	// 如果解析失败，使用总耗时作为近似值
	return float64(duration.Milliseconds()), true
}

func (pm *PingMonitor) parsePingOutput(output string) float64 {
	if runtime.GOOS == "windows" {
		// Windows ping输出格式: "时间<1ms" 或 "time<1ms" 或 "时间=1ms"
		re := regexp.MustCompile(`(?i)时间[=<](\d+)ms|time[=<](\d+)ms`)
		matches := re.FindStringSubmatch(output)
		if len(matches) > 1 {
			for i := 1; i < len(matches); i++ {
				if matches[i] != "" {
					if latency, err := strconv.ParseFloat(matches[i], 64); err == nil {
						return latency
					}
				}
			}
		}
		
		// 如果是 "<1ms" 的情况，返回1ms
		if strings.Contains(output, "时间<1ms") || strings.Contains(output, "time<1ms") {
			return 1.0
		}
	} else {
		// Linux/Mac ping输出格式: "time=1.234 ms"
		re := regexp.MustCompile(`time=([0-9.]+)\s*ms`)
		matches := re.FindStringSubmatch(output)
		if len(matches) > 1 {
			if latency, err := strconv.ParseFloat(matches[1], 64); err == nil {
				return latency
			}
		}
	}
	
	return 0
}

func (pm *PingMonitor) startPingLoop() {
	// 先执行一次初始ping测试
	fmt.Println("执行初始ping测试...")
	for _, target := range pm.config.Targets {
		latency, success := pm.ping(target.Addr)
		fmt.Printf("测试 %s (%s): ", target.Description, target.Addr)
		if success {
			fmt.Printf("%.2fms\n", latency)
		} else {
			fmt.Printf("失败\n")
		}
	}
	
	// 使用配置的ping间隔
	interval := time.Duration(pm.config.PingInterval) * time.Second
	fmt.Printf("开始定期ping监控，间隔: %v\n", interval)
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		for _, target := range pm.config.Targets {
			go func(t IPTarget) {
				latency, success := pm.ping(t.Addr)
				
				result := PingResult{
					Addr:        t.Addr,
					Description: t.Description,
					Latency:     latency,
					Success:     success,
					Timestamp:   time.Now(),
				}

				if err := pm.savePingResult(result); err != nil {
					fmt.Printf("保存数据失败: %v\n", err)
				}
				
				fmt.Printf("[%s] %s (%s): ", result.Timestamp.Format("15:04:05"), t.Description, t.Addr)
				if success {
					fmt.Printf("%.2fms\n", latency)
				} else {
					fmt.Printf("失败\n")
				}
			}(target)
		}
		<-ticker.C
	}
}

func (pm *PingMonitor) savePingResult(result PingResult) error {
	pm.dbMutex.Lock()
	defer pm.dbMutex.Unlock()
	
	query := `INSERT INTO ping_results (addr, description, latency, success, timestamp) 
			  VALUES (?, ?, ?, ?, ?)`
	
	_, err := pm.db.Exec(query, result.Addr, result.Description, result.Latency, result.Success, result.Timestamp)
	return err
}

func (pm *PingMonitor) startWebServer() {
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// 设置嵌入的静态文件系统
	staticSubFS, err := fs.Sub(staticFS, "static")
	if err != nil {
		log.Fatal("无法创建静态文件子系统:", err)
	}
	r.StaticFS("/static", http.FS(staticSubFS))

	// 设置嵌入的模板文件系统
	templatesSubFS, err := fs.Sub(templatesFS, "templates")
	if err != nil {
		log.Fatal("无法创建模板文件子系统:", err)
	}
	
	// 解析嵌入的模板
	tmpl := template.Must(template.New("").ParseFS(templatesSubFS, "*.html"))
	r.SetHTMLTemplate(tmpl)

	// 主页
	r.GET("/", func(c *gin.Context) {
		c.HTML(http.StatusOK, "index.html", gin.H{
			"targets": pm.config.Targets,
		})
	})

	// API: 获取ping数据
	r.GET("/api/ping-data", func(c *gin.Context) {
		addr := c.Query("addr")
		hours := c.DefaultQuery("hours", "1")
		
		h, _ := strconv.Atoi(hours)
		since := time.Now().Add(-time.Duration(h) * time.Hour)

		query := `SELECT addr, description, latency, success, timestamp 
				  FROM ping_results 
				  WHERE addr = ? AND timestamp > ? 
				  ORDER BY timestamp ASC`
		
		rows, err := pm.db.Query(query, addr, since)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		var results []PingResult
		for rows.Next() {
			var result PingResult
			err := rows.Scan(&result.Addr, &result.Description, &result.Latency, &result.Success, &result.Timestamp)
			if err != nil {
				continue
			}
			results = append(results, result)
		}

		c.JSON(http.StatusOK, results)
	})

	// API: 获取所有目标
	r.GET("/api/targets", func(c *gin.Context) {
		c.JSON(http.StatusOK, pm.config.Targets)
	})

	// API: 获取配置信息
	r.GET("/api/config", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"ping_interval": pm.config.PingInterval,
			"web_port":      pm.config.WebPort,
			"targets_count": len(pm.config.Targets),
		})
	})

	// API: 获取最新状态
	r.GET("/api/status", func(c *gin.Context) {
		query := `SELECT addr, description, latency, success, timestamp 
				  FROM ping_results 
				  WHERE (addr, timestamp) IN (
					  SELECT addr, MAX(timestamp) 
					  FROM ping_results 
					  GROUP BY addr
				  )`
		
		rows, err := pm.db.Query(query)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		var results []PingResult
		for rows.Next() {
			var result PingResult
			err := rows.Scan(&result.Addr, &result.Description, &result.Latency, &result.Success, &result.Timestamp)
			if err != nil {
				continue
			}
			results = append(results, result)
		}

		c.JSON(http.StatusOK, results)
	})

	fmt.Printf("Web服务器启动在 http://localhost:%d\n", pm.config.WebPort)
	log.Fatal(r.Run(fmt.Sprintf(":%d", pm.config.WebPort)))
}