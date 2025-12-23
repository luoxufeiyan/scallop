package main

import (
	"crypto/md5"
	"database/sql"
	"embed"
	"encoding/json"
	"fmt"
	"html/template"
	"io/fs"
	"log"
	"net"
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
	Addr        string `json:"addr"`                    // 支持IPv4、IPv6、域名
	Description string `json:"description"`             // 描述信息
	HideAddr    bool   `json:"hide_addr,omitempty"`     // 是否隐藏地址显示
	DNSServer   string `json:"dns_server,omitempty"`    // 自定义DNS服务器（仅域名时有效）
}

type Config struct {
	Targets      []IPTarget `json:"targets"`
	PingInterval int        `json:"ping_interval"` // ping间隔，单位：秒
	PingCount    int        `json:"ping_count"`    // 每次ping的次数，默认4次
	WebPort      int        `json:"web_port"`      // Web服务端口
	DefaultDNS   string     `json:"default_dns,omitempty"` // 默认DNS服务器
}

type Target struct {
	ID          string    `json:"id"`          // 目标唯一ID
	Addr        string    `json:"addr"`        // 地址
	Description string    `json:"description"` // 描述
	HideAddr    bool      `json:"hide_addr"`   // 是否隐藏地址
	DNSServer   string    `json:"dns_server"`  // DNS服务器
	CreatedAt   time.Time `json:"created_at"`  // 创建时间
	UpdatedAt   time.Time `json:"updated_at"`  // 更新时间
}

type PingResult struct {
	ID        int       `json:"id"`
	TargetID  string    `json:"target_id"`  // 关联目标ID
	Latency   float64   `json:"latency"`    // 毫秒
	Success   bool      `json:"success"`
	Timestamp time.Time `json:"timestamp"`
}

type PingMonitor struct {
	db           *sql.DB
	config       Config
	targets      map[string]*Target // 当前活跃目标，key为目标ID
	dbMutex      sync.Mutex
	configMutex  sync.RWMutex
	configPath   string
	lastModTime  time.Time
}

func main() {
	monitor := &PingMonitor{
		targets:    make(map[string]*Target),
		configPath: "config.json",
	}
	
	fmt.Println("正在启动Scallop网络延迟监控器...")
	
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
	
	// 初始化目标
	if err := monitor.initTargets(); err != nil {
		log.Fatal("初始化目标失败:", err)
	}
	
	fmt.Printf("已加载 %d 个监控目标\n", len(monitor.targets))
	for _, target := range monitor.targets {
		// Console打印显示真实地址
		fmt.Printf("- %s (%s)\n", target.Description, target.Addr)
	}
	fmt.Printf("Ping间隔: %d秒\n", monitor.config.PingInterval)
	fmt.Printf("Ping次数: %d次取平均\n", monitor.config.PingCount)
	fmt.Printf("Web端口: %d\n", monitor.config.WebPort)

	// 启动配置文件监控
	go monitor.watchConfig()

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

	// 创建目标表
	createTargetsSQL := `
	CREATE TABLE IF NOT EXISTS targets (
		id TEXT PRIMARY KEY,
		addr TEXT NOT NULL,
		description TEXT NOT NULL,
		hide_addr BOOLEAN DEFAULT FALSE,
		dns_server TEXT DEFAULT '',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);`
	
	// 创建ping结果表
	createResultsSQL := `
	CREATE TABLE IF NOT EXISTS ping_results (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		target_id TEXT NOT NULL,
		latency REAL NOT NULL,
		success BOOLEAN NOT NULL,
		timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (target_id) REFERENCES targets(id)
	);
	CREATE INDEX IF NOT EXISTS idx_target_timestamp ON ping_results(target_id, timestamp);
	CREATE INDEX IF NOT EXISTS idx_timestamp ON ping_results(timestamp);
	`
	
	// 执行创建表语句
	if _, err = pm.db.Exec(createTargetsSQL); err != nil {
		return fmt.Errorf("创建targets表失败: %v", err)
	}
	
	if _, err = pm.db.Exec(createResultsSQL); err != nil {
		return fmt.Errorf("创建ping_results表失败: %v", err)
	}
	
	return nil
}

// 生成目标ID
func (pm *PingMonitor) generateTargetID(addr, description string, hideAddr bool, dnsServer string) string {
	data := fmt.Sprintf("%s|%s|%t|%s", addr, description, hideAddr, dnsServer)
	hash := md5.Sum([]byte(data))
	return fmt.Sprintf("%x", hash)[:16] // 使用前16位作为ID
}

// 保存目标到数据库
func (pm *PingMonitor) saveTarget(target *Target) error {
	query := `INSERT OR REPLACE INTO targets (id, addr, description, hide_addr, dns_server, created_at, updated_at) 
			  VALUES (?, ?, ?, ?, ?, ?, ?)`
	
	_, err := pm.db.Exec(query, target.ID, target.Addr, target.Description, 
		target.HideAddr, target.DNSServer, target.CreatedAt, target.UpdatedAt)
	return err
}

// 从数据库加载目标
func (pm *PingMonitor) loadTargetsFromDB() error {
	rows, err := pm.db.Query("SELECT id, addr, description, hide_addr, dns_server, created_at, updated_at FROM targets")
	if err != nil {
		return err
	}
	defer rows.Close()
	
	pm.targets = make(map[string]*Target)
	for rows.Next() {
		target := &Target{}
		err := rows.Scan(&target.ID, &target.Addr, &target.Description, 
			&target.HideAddr, &target.DNSServer, &target.CreatedAt, &target.UpdatedAt)
		if err != nil {
			continue
		}
		pm.targets[target.ID] = target
	}
	
	return nil
}

// 初始化目标
func (pm *PingMonitor) initTargets() error {
	// 先从数据库加载现有目标
	if err := pm.loadTargetsFromDB(); err != nil {
		return err
	}
	
	// 根据配置文件更新目标
	return pm.updateTargetsFromConfig()
}

// 根据配置文件更新目标
func (pm *PingMonitor) updateTargetsFromConfig() error {
	pm.configMutex.RLock()
	configTargets := make([]IPTarget, len(pm.config.Targets))
	copy(configTargets, pm.config.Targets)
	pm.configMutex.RUnlock()
	
	// 创建新的目标映射
	newTargets := make(map[string]*Target)
	
	for _, configTarget := range configTargets {
		targetID := pm.generateTargetID(configTarget.Addr, configTarget.Description, 
			configTarget.HideAddr, configTarget.DNSServer)
		
		// 检查是否已存在
		if existingTarget, exists := pm.targets[targetID]; exists {
			existingTarget.UpdatedAt = time.Now()
			newTargets[targetID] = existingTarget
		} else {
			// 创建新目标
			target := &Target{
				ID:          targetID,
				Addr:        configTarget.Addr,
				Description: configTarget.Description,
				HideAddr:    configTarget.HideAddr,
				DNSServer:   configTarget.DNSServer,
				CreatedAt:   time.Now(),
				UpdatedAt:   time.Now(),
			}
			
			if err := pm.saveTarget(target); err != nil {
				return err
			}
			
			newTargets[targetID] = target
			fmt.Printf("添加新目标: %s (%s)\n", target.Description, target.Addr)
		}
	}
	
	pm.targets = newTargets
	return nil
}

// 监控配置文件变化
func (pm *PingMonitor) watchConfig() {
	ticker := time.NewTicker(5 * time.Second) // 每5秒检查一次
	defer ticker.Stop()
	
	for {
		<-ticker.C
		
		stat, err := os.Stat(pm.configPath)
		if err != nil {
			continue
		}
		
		if stat.ModTime().After(pm.lastModTime) {
			fmt.Println("检测到配置文件变化，重新加载...")
			
			if err := pm.loadConfig(); err != nil {
				fmt.Printf("重新加载配置失败: %v\n", err)
				continue
			}
			
			if err := pm.updateTargetsFromConfig(); err != nil {
				fmt.Printf("更新目标失败: %v\n", err)
				continue
			}
			
			pm.lastModTime = stat.ModTime()
			fmt.Println("配置重新加载完成")
		}
	}
}

func (pm *PingMonitor) loadConfig() error {
	// 记录文件修改时间
	if stat, err := os.Stat(pm.configPath); err == nil {
		pm.lastModTime = stat.ModTime()
	}
	
	// 检查配置文件是否存在
	if _, err := os.Stat(pm.configPath); os.IsNotExist(err) {
		// 创建默认配置
		defaultConfig := Config{
			Targets: []IPTarget{
				{Addr: "8.8.8.8", Description: "Google DNS", HideAddr: false},
				{Addr: "114.114.114.114", Description: "114 DNS", HideAddr: false},
				{Addr: "1.1.1.1", Description: "Cloudflare DNS", HideAddr: false},
				{Addr: "2001:4860:4860::8888", Description: "Google DNS IPv6", HideAddr: false},
				{Addr: "github.com", Description: "GitHub", HideAddr: false, DNSServer: "8.8.8.8"},
			},
			PingInterval: 10,   // 默认10秒
			PingCount:    4,    // 默认4次ping取平均
			WebPort:      8081, // 默认端口8081
			DefaultDNS:   "",   // 使用系统默认DNS
		}
		
		data, _ := json.MarshalIndent(defaultConfig, "", "  ")
		if err := os.WriteFile(pm.configPath, data, 0644); err != nil {
			return err
		}
		
		pm.configMutex.Lock()
		pm.config = defaultConfig
		pm.configMutex.Unlock()
		return nil
	}

	// 读取配置文件
	data, err := os.ReadFile(pm.configPath)
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
			PingCount:    4,    // 默认4次
			WebPort:      8081, // 默认端口8081
			DefaultDNS:   "",   // 使用系统默认DNS
		}
		// 保存新格式的配置
		data, _ := json.MarshalIndent(config, "", "  ")
		os.WriteFile(pm.configPath, data, 0644)
	}

	// 验证配置值
	if config.PingInterval <= 0 {
		config.PingInterval = 10
	}
	if config.PingCount <= 0 || config.PingCount > 10 {
		config.PingCount = 4 // 默认4次
	}
	if config.WebPort <= 0 || config.WebPort > 65535 {
		config.WebPort = 8081
	}

	pm.configMutex.Lock()
	pm.config = config
	pm.configMutex.Unlock()
	return nil
}

func (pm *PingMonitor) ping(target *Target) (float64, bool) {
	// 获取配置的ping次数
	pm.configMutex.RLock()
	pingCount := pm.config.PingCount
	pm.configMutex.RUnlock()
	
	// 解析地址，支持IPv4、IPv6和域名
	addr := target.Addr
	
	// 如果是域名，先进行DNS解析
	if !pm.isIPAddress(addr) {
		resolvedAddr, err := pm.resolveAddress(addr, target.DNSServer)
		if err != nil {
			fmt.Printf("DNS解析失败 %s: %v\n", addr, err)
			return 0, false
		}
		addr = resolvedAddr
	}
	
	// 执行多次ping并收集结果
	var latencies []float64
	successCount := 0
	
	for i := 0; i < pingCount; i++ {
		latency, success := pm.singlePing(addr)
		if success {
			latencies = append(latencies, latency)
			successCount++
		}
	}
	
	// 如果所有ping都失败，返回失败
	if successCount == 0 {
		return 0, false
	}
	
	// 计算平均延迟
	var sum float64
	for _, latency := range latencies {
		sum += latency
	}
	avgLatency := sum / float64(len(latencies))
	
	return avgLatency, true
}

// 执行单次ping
func (pm *PingMonitor) singlePing(addr string) (float64, bool) {
	start := time.Now()
	
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		// Windows ping命令，自动检测IPv4/IPv6
		if strings.Contains(addr, ":") {
			// IPv6
			cmd = exec.Command("ping", "-6", "-n", "1", "-w", "3000", addr)
		} else {
			// IPv4
			cmd = exec.Command("ping", "-4", "-n", "1", "-w", "3000", addr)
		}
	} else {
		// Linux/Mac ping命令
		if strings.Contains(addr, ":") {
			// IPv6
			cmd = exec.Command("ping6", "-c", "1", "-W", "3", addr)
		} else {
			// IPv4
			cmd = exec.Command("ping", "-c", "1", "-W", "3", addr)
		}
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

// 检查是否为IP地址
func (pm *PingMonitor) isIPAddress(addr string) bool {
	return net.ParseIP(addr) != nil
}

// 解析域名地址
func (pm *PingMonitor) resolveAddress(hostname, dnsServer string) (string, error) {
	// 如果指定了DNS服务器，使用nslookup或dig
	if dnsServer != "" {
		return pm.resolveWithCustomDNS(hostname, dnsServer)
	}
	
	// 使用系统默认DNS
	ips, err := net.LookupIP(hostname)
	if err != nil {
		return "", err
	}
	
	if len(ips) == 0 {
		return "", fmt.Errorf("无法解析域名: %s", hostname)
	}
	
	// 优先返回IPv4地址
	for _, ip := range ips {
		if ip.To4() != nil {
			return ip.String(), nil
		}
	}
	
	// 如果没有IPv4，返回IPv6
	return ips[0].String(), nil
}

// 使用自定义DNS服务器解析域名
func (pm *PingMonitor) resolveWithCustomDNS(hostname, dnsServer string) (string, error) {
	var cmd *exec.Cmd
	
	if runtime.GOOS == "windows" {
		// Windows使用nslookup
		cmd = exec.Command("nslookup", hostname, dnsServer)
	} else {
		// Linux/Mac优先使用dig，如果没有则使用nslookup
		if _, err := exec.LookPath("dig"); err == nil {
			cmd = exec.Command("dig", "+short", "@"+dnsServer, hostname)
		} else {
			cmd = exec.Command("nslookup", hostname, dnsServer)
		}
	}
	
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	
	return pm.parseResolveOutput(string(output))
}

// 解析DNS查询输出
func (pm *PingMonitor) parseResolveOutput(output string) (string, error) {
	lines := strings.Split(output, "\n")
	
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		
		// 检查是否为IP地址
		if net.ParseIP(line) != nil {
			return line, nil
		}
		
		// 解析nslookup输出
		if strings.Contains(line, "Address:") && !strings.Contains(line, "#") {
			parts := strings.Split(line, ":")
			if len(parts) >= 2 {
				ip := strings.TrimSpace(parts[1])
				if net.ParseIP(ip) != nil {
					return ip, nil
				}
			}
		}
	}
	
	return "", fmt.Errorf("无法从DNS输出中解析IP地址")
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
	for _, target := range pm.targets {
		latency, success := pm.ping(target)
		// Console打印显示真实地址
		fmt.Printf("测试 %s (%s): ", target.Description, target.Addr)
		if success {
			fmt.Printf("%.2fms\n", latency)
		} else {
			fmt.Printf("失败\n")
		}
	}
	
	// 使用配置的ping间隔
	pm.configMutex.RLock()
	interval := time.Duration(pm.config.PingInterval) * time.Second
	pm.configMutex.RUnlock()
	
	fmt.Printf("开始定期ping监控，间隔: %v\n", interval)
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		// 获取当前目标列表的快照
		currentTargets := make([]*Target, 0, len(pm.targets))
		for _, target := range pm.targets {
			currentTargets = append(currentTargets, target)
		}
		
		for _, target := range currentTargets {
			go func(t *Target) {
				latency, success := pm.ping(t)
				
				result := PingResult{
					TargetID:  t.ID,
					Latency:   latency,
					Success:   success,
					Timestamp: time.Now(),
				}

				if err := pm.savePingResult(result); err != nil {
					fmt.Printf("保存数据失败: %v\n", err)
				}
				
				displayAddr := t.Addr
				
				fmt.Printf("[%s] %s (%s): ", result.Timestamp.Format("15:04:05"), t.Description, displayAddr)
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
	
	query := `INSERT INTO ping_results (target_id, latency, success, timestamp) 
			  VALUES (?, ?, ?, ?)`
	
	_, err := pm.db.Exec(query, result.TargetID, result.Latency, result.Success, result.Timestamp)
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
		// 转换目标为前端格式
		var displayTargets []map[string]interface{}
		for _, target := range pm.targets {
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
	})

	// API: 获取ping数据
	r.GET("/api/ping-data", func(c *gin.Context) {
		targetID := c.Query("target_id")
		addr := c.Query("addr") // 兼容旧API
		hours := c.DefaultQuery("hours", "1")
		
		h, _ := strconv.Atoi(hours)
		since := time.Now().Add(-time.Duration(h) * time.Hour)

		var query string
		var args []interface{}
		
		if targetID != "" {
			// 使用新的target_id查询
			query = `SELECT pr.target_id, t.addr, t.description, t.hide_addr, pr.latency, pr.success, pr.timestamp 
					 FROM ping_results pr 
					 JOIN targets t ON pr.target_id = t.id 
					 WHERE pr.target_id = ? AND pr.timestamp > ? 
					 ORDER BY pr.timestamp ASC`
			args = []interface{}{targetID, since}
		} else if addr != "" {
			// 兼容旧API，通过地址查询
			query = `SELECT pr.target_id, t.addr, t.description, t.hide_addr, pr.latency, pr.success, pr.timestamp 
					 FROM ping_results pr 
					 JOIN targets t ON pr.target_id = t.id 
					 WHERE t.addr = ? AND pr.timestamp > ? 
					 ORDER BY pr.timestamp ASC`
			args = []interface{}{addr, since}
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "需要提供target_id或addr参数"})
			return
		}
		
		rows, err := pm.db.Query(query, args...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

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

		c.JSON(http.StatusOK, results)
	})

	// API: 获取所有目标
	r.GET("/api/targets", func(c *gin.Context) {
		var displayTargets []map[string]interface{}
		for _, target := range pm.targets {
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
	})

	// API: 获取配置信息
	r.GET("/api/config", func(c *gin.Context) {
		pm.configMutex.RLock()
		config := pm.config
		pm.configMutex.RUnlock()
		
		c.JSON(http.StatusOK, gin.H{
			"ping_interval": config.PingInterval,
			"ping_count":    config.PingCount,
			"web_port":      config.WebPort,
			"default_dns":   config.DefaultDNS,
			"targets_count": len(pm.targets),
		})
	})

	// API: 获取最新状态
	r.GET("/api/status", func(c *gin.Context) {
		query := `SELECT pr.target_id, t.addr, t.description, t.hide_addr, pr.latency, pr.success, pr.timestamp 
				  FROM ping_results pr 
				  JOIN targets t ON pr.target_id = t.id 
				  WHERE (pr.target_id, pr.timestamp) IN (
					  SELECT target_id, MAX(timestamp) 
					  FROM ping_results 
					  GROUP BY target_id
				  )`
		
		rows, err := pm.db.Query(query)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

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

		c.JSON(http.StatusOK, results)
	})

	pm.configMutex.RLock()
	webPort := pm.config.WebPort
	pm.configMutex.RUnlock()
	
	fmt.Printf("Web服务器启动在 http://localhost:%d\n", webPort)
	log.Fatal(r.Run(fmt.Sprintf(":%d", webPort)))
}