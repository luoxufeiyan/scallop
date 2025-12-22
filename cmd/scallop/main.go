package main

import (
	"flag"
	"fmt"
	"log"
	"path/filepath"

	"scallop/internal/config"
	"scallop/internal/database"
	"scallop/internal/monitor"
	"scallop/internal/web"
)

func main() {
	// 解析命令行参数
	configPath := flag.String("config", "config.json", "配置文件路径")
	dataDir := flag.String("data", "", "数据目录路径（默认为当前目录）")
	flag.Parse()

	fmt.Println("正在启动Scallop网络延迟监控器...")

	// 初始化配置管理器
	fmt.Printf("加载配置文件: %s\n", *configPath)
	configManager := config.NewManager(*configPath)
	if err := configManager.Load(); err != nil {
		log.Fatal("加载配置失败:", err)
	}

	// 确定数据库路径
	var dbPath string
	if *dataDir != "" {
		dbPath = filepath.Join(*dataDir, "ping_data.db")
	} else {
		dbPath = "./ping_data.db"
	}

	// 初始化数据库
	fmt.Printf("初始化数据库: %s\n", dbPath)
	db, err := database.New(dbPath)
	if err != nil {
		log.Fatal("初始化数据库失败:", err)
	}
	defer db.Close()

	// 初始化目标
	cfg := configManager.Get()
	if err := db.UpdateTargetsFromConfig(cfg.Targets); err != nil {
		log.Fatal("初始化目标失败:", err)
	}

	// 显示加载的目标
	targets := db.GetTargets()
	fmt.Printf("已加载 %d 个监控目标\n", len(targets))
	for _, target := range targets {
		// Console打印显示真实地址
		fmt.Printf("- %s (%s)\n", target.Description, target.Addr)
	}
	fmt.Printf("Ping间隔: %d秒\n", cfg.PingInterval)
	fmt.Printf("Ping次数: %d次取平均\n", cfg.PingCount)
	fmt.Printf("Web端口: %d\n", cfg.WebPort)

	// 启动监控器
	fmt.Println("启动ping监控...")
	mon := monitor.NewMonitor(db, configManager)
	mon.Start()

	// 启动Web服务器
	fmt.Println("启动Web服务器...")
	server := web.NewServer(db, configManager)
	if err := server.Start(); err != nil {
		log.Fatal("启动Web服务器失败:", err)
	}
}
