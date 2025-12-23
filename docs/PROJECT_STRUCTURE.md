# Scallop 项目结构说明

## 目录结构

```
scallop/
├── cmd/                    # 应用程序入口
│   └── scallop/           # 主程序
│       └── main.go        # 程序入口点
│
├── internal/              # 内部包（不对外暴露）
│   ├── config/           # 配置管理
│   │   └── config.go     # 配置加载、验证、监控
│   ├── database/         # 数据库操作
│   │   └── database.go   # 数据库初始化、目标管理、结果保存
│   ├── models/           # 数据模型
│   │   └── models.go     # 数据结构定义
│   ├── monitor/          # 监控器
│   │   └── monitor.go    # Ping监控循环、配置监控
│   ├── ping/             # Ping功能
│   │   └── ping.go       # Ping执行、DNS解析
│   └── web/              # Web服务器
│       ├── server.go     # HTTP服务器、API路由
│       ├── static/       # 静态资源
│       │   └── app.js    # 前端JavaScript
│       └── templates/    # HTML模板
│           └── index.html
│
├── docs/                  # 文档
│   ├── BUILD.md          # 构建说明
│   ├── CHANGELOG.md      # 更新日志
│   ├── DEPLOYMENT.md     # 部署指南
│   ├── FEATURES.md       # 功能说明
│   └── PROJECT_STRUCTURE.md  # 项目结构说明（本文件）
│
├── scripts/               # 脚本
│   ├── build.bat         # Windows构建脚本
│   ├── build-simple.bat  # Windows简单构建
│   ├── build.ps1         # PowerShell构建脚本
│   ├── build.sh          # Linux/Mac构建脚本
│   ├── run.bat           # Windows运行脚本
│   └── Makefile          # Make构建文件
│
├── config.json            # 配置文件
├── config.example.json    # 配置示例
├── go.mod                 # Go模块定义
├── go.sum                 # Go依赖锁定
├── LICENSE                # 许可证
├── README.md              # 项目说明
└── .gitignore             # Git忽略文件

```

## 模块说明

### cmd/scallop
程序入口点，负责：
- 初始化各个组件
- 协调各模块的启动顺序
- 处理程序生命周期

### internal/config
配置管理模块，负责：
- 加载和解析配置文件
- 配置验证和默认值设置
- 配置文件变化监控

### internal/database
数据库管理模块，负责：
- 数据库初始化和表创建
- 目标的增删改查
- Ping结果的保存和查询
- 目标ID生成

### internal/models
数据模型定义，包含：
- IPTarget: 配置文件中的目标定义
- Config: 应用配置结构
- Target: 数据库中的目标记录
- PingResult: Ping测试结果

### internal/monitor
监控器模块，负责：
- 定期执行Ping测试
- 监控配置文件变化
- 协调Ping执行和结果保存

### internal/ping
Ping功能模块，负责：
- 执行Ping命令
- DNS域名解析
- Ping结果解析
- 支持IPv4/IPv6

### internal/web
Web服务器模块，负责：
- HTTP服务器启动
- API路由处理
- 静态文件服务
- HTML模板渲染

## 构建和运行

### 开发模式
```bash
# 直接运行
go run cmd/scallop/main.go

# 或使用脚本
scripts/run.bat  # Windows
```

### 构建
```bash
# 使用构建脚本
scripts/build.bat      # Windows
scripts/build.sh       # Linux/Mac

# 或使用Go命令
go build -o scallop.exe cmd/scallop/main.go
```

### 跨平台构建
```bash
# Windows
scripts/build.bat

# Linux/Mac
scripts/build.sh

# 使用Makefile
cd scripts && make all
```

## 代码组织原则

1. **单一职责**: 每个包只负责一个明确的功能领域
2. **依赖注入**: 通过构造函数传递依赖，便于测试
3. **接口隔离**: 模块间通过清晰的接口通信
4. **配置集中**: 所有配置通过config包统一管理
5. **错误处理**: 明确的错误返回和日志记录

## 添加新功能

### 添加新的API端点
1. 在 `internal/web/server.go` 中添加处理函数
2. 在 `registerRoutes` 中注册路由
3. 更新前端代码调用新API

### 添加新的配置项
1. 在 `internal/models/models.go` 中更新Config结构
2. 在 `internal/config/config.go` 中添加验证逻辑
3. 更新 `config.example.json`

### 添加新的数据表
1. 在 `internal/database/database.go` 的 `init` 方法中添加建表SQL
2. 添加相应的查询和保存方法
3. 在 `internal/models/models.go` 中定义数据结构

## 测试

```bash
# 运行所有测试
go test ./...

# 运行特定包的测试
go test ./internal/ping
go test ./internal/config

# 带覆盖率
go test -cover ./...
```

## 性能优化建议

1. **数据库查询**: 使用索引，避免全表扫描
2. **并发控制**: 合理使用goroutine和channel
3. **内存管理**: 及时释放不用的资源
4. **缓存策略**: 对频繁访问的数据进行缓存
