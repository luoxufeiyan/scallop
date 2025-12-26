package monitor

import (
	"fmt"
	"os"
	"time"

	"scallop/internal/config"
	"scallop/internal/database"
	"scallop/internal/models"
	"scallop/internal/ping"
)

// Monitor Ping监控器
type Monitor struct {
	db            *database.DB
	configManager *config.Manager
	pingExecutor  *ping.Executor
}

// NewMonitor 创建监控器
func NewMonitor(db *database.DB, configManager *config.Manager) *Monitor {
	config := configManager.Get()
	return &Monitor{
		db:            db,
		configManager: configManager,
		pingExecutor:  ping.NewExecutor(config.PingCount),
	}
}

// Start 启动监控
func (m *Monitor) Start() {
	// 先执行一次初始ping测试
	fmt.Println("执行初始ping测试...")
	m.runPingTests()

	// 启动配置文件监控
	go m.watchConfig()

	// 启动定期ping监控
	go m.startPingLoop()
}

// runPingTests 执行ping测试
func (m *Monitor) runPingTests() {
	targets := m.db.GetTargets()
	for _, target := range targets {
		latency, success := m.pingExecutor.Ping(target)
		// Console打印显示真实地址
		fmt.Printf("测试 %s (%s): ", target.Description, target.Addr)
		if success {
			fmt.Printf("%.2fms\n", latency)
		} else {
			fmt.Printf("失败\n")
		}
	}
}

// startPingLoop 启动定期ping循环
func (m *Monitor) startPingLoop() {
	config := m.configManager.Get()
	interval := time.Duration(config.PingInterval) * time.Second

	fmt.Printf("开始定期ping监控，间隔: %v\n", interval)
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		// 获取当前目标列表的快照
		targets := m.db.GetTargets()
		currentTargets := make([]*models.Target, 0, len(targets))
		for _, target := range targets {
			currentTargets = append(currentTargets, target)
		}

		for _, target := range currentTargets {
			go m.pingAndSave(target)
		}
		<-ticker.C
	}
}

// pingAndSave 执行ping并保存结果
func (m *Monitor) pingAndSave(target *models.Target) {
	latency, success := m.pingExecutor.Ping(target)

	result := models.PingResult{
		TargetID:  target.ID,
		Latency:   latency,
		Success:   success,
		Timestamp: time.Now(),
	}

	if err := m.db.SavePingResult(result); err != nil {
		fmt.Printf("保存数据失败: %v\n", err)
	}

	fmt.Printf("[%s] %s (%s): ", result.Timestamp.Format("15:04:05"), target.Description, target.Addr)
	if success {
		fmt.Printf("%.2fms\n", latency)
	} else {
		fmt.Printf("失败\n")
	}
}

// watchConfig 监控配置文件变化
func (m *Monitor) watchConfig() {
	ticker := time.NewTicker(5 * time.Second) // 每5秒检查一次
	defer ticker.Stop()

	for {
		<-ticker.C

		stat, err := os.Stat(m.configManager.GetConfigPath())
		if err != nil {
			continue
		}

		if stat.ModTime().After(m.configManager.GetLastModTime()) {
			fmt.Println("检测到配置文件变化，重新加载...")

			// 保存旧的目标列表
			oldTargets := m.db.GetTargets()
			oldTargetIDs := make(map[string]bool)
			for id := range oldTargets {
				oldTargetIDs[id] = true
			}

			if err := m.configManager.Load(); err != nil {
				fmt.Printf("重新加载配置失败: %v\n", err)
				continue
			}

			config := m.configManager.Get()
			if err := m.db.UpdateTargetsFromConfig(config.Targets); err != nil {
				fmt.Printf("更新目标失败: %v\n", err)
				continue
			}

			// 更新ping执行器的ping次数
			m.pingExecutor = ping.NewExecutor(config.PingCount)

			// 检测新增的目标并立即进行ping测试
			newTargets := m.db.GetTargets()
			for id, target := range newTargets {
				if !oldTargetIDs[id] {
					fmt.Printf("检测到新目标，立即进行ping测试: %s (%s)\n", target.Description, target.Addr)
					go m.pingAndSave(target)
				}
			}

			fmt.Println("配置重新加载完成")
		}
	}
}
