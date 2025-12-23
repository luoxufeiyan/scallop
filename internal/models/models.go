package models

import "time"

// IPTarget 配置文件中的目标定义
type IPTarget struct {
	Addr        string `json:"addr"`                    // 支持IPv4、IPv6、域名
	Description string `json:"description"`             // 描述信息
	HideAddr    bool   `json:"hide_addr,omitempty"`     // 是否隐藏地址显示
	DNSServer   string `json:"dns_server,omitempty"`    // 自定义DNS服务器（仅域名时有效）
}

// Config 应用配置
type Config struct {
	Targets      []IPTarget `json:"targets"`
	PingInterval int        `json:"ping_interval"` // ping间隔，单位：秒
	PingCount    int        `json:"ping_count"`    // 每次ping的次数，默认4次
	WebPort      int        `json:"web_port"`      // Web服务端口
	DefaultDNS   string     `json:"default_dns,omitempty"` // 默认DNS服务器
}

// Target 数据库中的目标
type Target struct {
	ID          string    `json:"id"`          // 目标唯一ID
	Addr        string    `json:"addr"`        // 地址
	Description string    `json:"description"` // 描述
	HideAddr    bool      `json:"hide_addr"`   // 是否隐藏地址
	DNSServer   string    `json:"dns_server"`  // DNS服务器
	CreatedAt   time.Time `json:"created_at"`  // 创建时间
	UpdatedAt   time.Time `json:"updated_at"`  // 更新时间
}

// PingResult Ping结果
type PingResult struct {
	ID        int       `json:"id"`
	TargetID  string    `json:"target_id"`  // 关联目标ID
	Latency   float64   `json:"latency"`    // 毫秒
	Success   bool      `json:"success"`
	Timestamp time.Time `json:"timestamp"`
}
