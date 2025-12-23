package config

import (
	"encoding/json"
	"os"
	"sync"
	"time"

	"scallop/internal/models"
)

// Manager 配置管理器
type Manager struct {
	config      models.Config
	mutex       sync.RWMutex
	configPath  string
	lastModTime time.Time
}

// NewManager 创建配置管理器
func NewManager(configPath string) *Manager {
	return &Manager{
		configPath: configPath,
	}
}

// Load 加载配置
func (m *Manager) Load() error {
	// 记录文件修改时间
	if stat, err := os.Stat(m.configPath); err == nil {
		m.lastModTime = stat.ModTime()
	}

	// 检查配置文件是否存在
	if _, err := os.Stat(m.configPath); os.IsNotExist(err) {
		return m.createDefaultConfig()
	}

	// 读取配置文件
	data, err := os.ReadFile(m.configPath)
	if err != nil {
		return err
	}

	// 尝试解析新格式的配置
	var config models.Config
	if err := json.Unmarshal(data, &config); err != nil {
		// 如果解析失败，尝试解析旧格式（只有targets数组）
		var targets []models.IPTarget
		if err := json.Unmarshal(data, &targets); err != nil {
			return err
		}
		// 转换为新格式
		config = models.Config{
			Targets:      targets,
			PingInterval: 10,
			PingCount:    4,
			WebPort:      8081,
			DefaultDNS:   "",
		}
		// 保存新格式的配置
		data, _ := json.MarshalIndent(config, "", "  ")
		os.WriteFile(m.configPath, data, 0644)
	}

	// 验证配置值
	m.validateConfig(&config)

	m.mutex.Lock()
	m.config = config
	m.mutex.Unlock()
	return nil
}

// createDefaultConfig 创建默认配置
func (m *Manager) createDefaultConfig() error {
	defaultConfig := models.Config{
		Title:       "Scallop - 网络延迟监控",
		Description: "",
		Targets: []models.IPTarget{
			{Addr: "8.8.8.8", Description: "Google DNS", HideAddr: false},
			{Addr: "114.114.114.114", Description: "114 DNS", HideAddr: false},
			{Addr: "1.1.1.1", Description: "Cloudflare DNS", HideAddr: false},
			{Addr: "2001:4860:4860::8888", Description: "Google DNS IPv6", HideAddr: false},
			{Addr: "github.com", Description: "GitHub", HideAddr: false, DNSServer: "8.8.8.8"},
		},
		PingInterval: 10,
		PingCount:    4,
		WebPort:      8081,
		DefaultDNS:   "",
	}

	data, _ := json.MarshalIndent(defaultConfig, "", "  ")
	if err := os.WriteFile(m.configPath, data, 0644); err != nil {
		return err
	}

	m.mutex.Lock()
	m.config = defaultConfig
	m.mutex.Unlock()
	return nil
}

// validateConfig 验证配置值
func (m *Manager) validateConfig(config *models.Config) {
	if config.PingInterval <= 0 {
		config.PingInterval = 10
	}
	if config.PingCount <= 0 || config.PingCount > 10 {
		config.PingCount = 4
	}
	if config.WebPort <= 0 || config.WebPort > 65535 {
		config.WebPort = 8081
	}
}

// Get 获取配置
func (m *Manager) Get() models.Config {
	m.mutex.RLock()
	defer m.mutex.RUnlock()
	return m.config
}

// GetLastModTime 获取最后修改时间
func (m *Manager) GetLastModTime() time.Time {
	return m.lastModTime
}

// GetConfigPath 获取配置文件路径
func (m *Manager) GetConfigPath() string {
	return m.configPath
}
