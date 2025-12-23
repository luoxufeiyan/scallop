package database

import (
	"crypto/md5"
	"database/sql"
	"fmt"
	"sync"
	"time"

	"scallop/internal/models"

	_ "modernc.org/sqlite"
)

// DB 数据库管理器
type DB struct {
	conn    *sql.DB
	mutex   sync.Mutex
	targets map[string]*models.Target // 当前活跃目标，key为目标ID
}

// New 创建数据库管理器
func New(dbPath string) (*DB, error) {
	conn, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}

	db := &DB{
		conn:    conn,
		targets: make(map[string]*models.Target),
	}

	if err := db.init(); err != nil {
		return nil, err
	}

	return db, nil
}

// init 初始化数据库表
func (db *DB) init() error {
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
	if _, err := db.conn.Exec(createTargetsSQL); err != nil {
		return fmt.Errorf("创建targets表失败: %v", err)
	}

	if _, err := db.conn.Exec(createResultsSQL); err != nil {
		return fmt.Errorf("创建ping_results表失败: %v", err)
	}

	return nil
}

// Close 关闭数据库连接
func (db *DB) Close() error {
	return db.conn.Close()
}

// GetConn 获取数据库连接
func (db *DB) GetConn() *sql.DB {
	return db.conn
}

// GenerateTargetID 生成目标ID
func GenerateTargetID(addr, description string, hideAddr bool, dnsServer string) string {
	data := fmt.Sprintf("%s|%s|%t|%s", addr, description, hideAddr, dnsServer)
	hash := md5.Sum([]byte(data))
	return fmt.Sprintf("%x", hash)[:16] // 使用前16位作为ID
}

// SaveTarget 保存目标到数据库
func (db *DB) SaveTarget(target *models.Target) error {
	query := `INSERT OR REPLACE INTO targets (id, addr, description, hide_addr, dns_server, created_at, updated_at) 
			  VALUES (?, ?, ?, ?, ?, ?, ?)`

	_, err := db.conn.Exec(query, target.ID, target.Addr, target.Description,
		target.HideAddr, target.DNSServer, target.CreatedAt, target.UpdatedAt)
	return err
}

// LoadTargets 从数据库加载目标
func (db *DB) LoadTargets() (map[string]*models.Target, error) {
	rows, err := db.conn.Query("SELECT id, addr, description, hide_addr, dns_server, created_at, updated_at FROM targets")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	targets := make(map[string]*models.Target)
	for rows.Next() {
		target := &models.Target{}
		err := rows.Scan(&target.ID, &target.Addr, &target.Description,
			&target.HideAddr, &target.DNSServer, &target.CreatedAt, &target.UpdatedAt)
		if err != nil {
			continue
		}
		targets[target.ID] = target
	}

	return targets, nil
}

// SavePingResult 保存Ping结果
func (db *DB) SavePingResult(result models.PingResult) error {
	db.mutex.Lock()
	defer db.mutex.Unlock()

	query := `INSERT INTO ping_results (target_id, latency, success, timestamp) 
			  VALUES (?, ?, ?, ?)`

	_, err := db.conn.Exec(query, result.TargetID, result.Latency, result.Success, result.Timestamp)
	return err
}

// GetTargets 获取当前目标列表
func (db *DB) GetTargets() map[string]*models.Target {
	return db.targets
}

// SetTargets 设置目标列表
func (db *DB) SetTargets(targets map[string]*models.Target) {
	db.targets = targets
}

// UpdateTargetsFromConfig 根据配置更新目标
func (db *DB) UpdateTargetsFromConfig(configTargets []models.IPTarget) error {
	// 先从数据库加载现有目标
	existingTargets, err := db.LoadTargets()
	if err != nil {
		return err
	}

	// 创建新的目标映射
	newTargets := make(map[string]*models.Target)

	for _, configTarget := range configTargets {
		targetID := GenerateTargetID(configTarget.Addr, configTarget.Description,
			configTarget.HideAddr, configTarget.DNSServer)

		// 检查是否已存在
		if existingTarget, exists := existingTargets[targetID]; exists {
			existingTarget.UpdatedAt = time.Now()
			newTargets[targetID] = existingTarget
		} else {
			// 创建新目标
			target := &models.Target{
				ID:          targetID,
				Addr:        configTarget.Addr,
				Description: configTarget.Description,
				HideAddr:    configTarget.HideAddr,
				DNSServer:   configTarget.DNSServer,
				CreatedAt:   time.Now(),
				UpdatedAt:   time.Now(),
			}

			if err := db.SaveTarget(target); err != nil {
				return err
			}

			newTargets[targetID] = target
			fmt.Printf("添加新目标: %s (%s)\n", target.Description, target.Addr)
		}
	}

	db.targets = newTargets
	return nil
}
