# 项目重构说明

## 重构内容

本次重构将原来的单文件 `main.go` (850+ 行) 拆分为多个模块化的包，提高了代码的可维护性和可测试性。

## 新的项目结构

```
scallop/
├── cmd/scallop/          # 主程序入口
├── internal/             # 内部包
│   ├── config/          # 配置管理
│   ├── database/        # 数据库操作
│   ├── models/          # 数据模型
│   ├── monitor/         # 监控器
│   ├── ping/            # Ping功能
│   └── web/             # Web服务器
├── docs/                 # 文档（原来的 *.md 文件）
├── scripts/              # 构建脚本（原来的 build*.bat 等）
├── config.json           # 配置文件
└── README.md             # 项目说明
```

## 模块职责

### cmd/scallop/main.go
- 程序入口点
- 初始化各个组件
- 协调启动流程

### internal/config
- 配置文件加载和解析
- 配置验证
- 配置文件监控

### internal/database
- 数据库初始化
- 目标管理（CRUD）
- Ping结果存储
- 数据查询

### internal/models
- 数据结构定义
- IPTarget, Config, Target, PingResult

### internal/monitor
- Ping监控循环
- 配置变化监控
- 结果保存协调

### internal/ping
- Ping命令执行
- DNS解析
- 结果解析
- 支持IPv4/IPv6

### internal/web
- HTTP服务器
- API路由
- 静态文件服务
- HTML模板渲染

## 构建和运行

### 开发模式
```bash
# Windows
scripts\run.bat

# Linux/Mac
go run cmd/scallop/main.go
```

### 编译
```bash
# 简单编译
cd scripts
build-simple.bat  # Windows

# 完整编译（所有平台）
cd scripts
build.bat  # Windows
```

## 迁移说明

### 对于开发者
1. 主程序入口从 `main.go` 改为 `cmd/scallop/main.go`
2. 所有构建脚本已更新，使用方式不变
3. 配置文件位置不变，仍在项目根目录
4. 数据库文件位置不变

### 对于用户
- **无需任何改动**
- 编译后的二进制文件使用方式完全相同
- 配置文件格式和位置不变
- Web界面和API完全兼容

## 优势

1. **代码组织清晰**: 每个模块职责明确，易于理解
2. **易于维护**: 修改某个功能只需关注对应的包
3. **便于测试**: 每个包可以独立测试
4. **扩展性好**: 添加新功能更容易
5. **团队协作**: 多人开发时减少冲突

## 向后兼容

- ✅ 配置文件格式完全兼容
- ✅ API接口完全兼容
- ✅ 数据库结构完全兼容
- ✅ Web界面完全兼容
- ✅ 编译产物使用方式完全兼容

## 文件变更

### 新增
- `cmd/scallop/main.go` - 新的主程序入口
- `internal/` - 所有内部包
- `docs/` - 文档目录
- `scripts/` - 脚本目录
- `docs/PROJECT_STRUCTURE.md` - 项目结构说明

### 移动
- `BUILD.md` → `docs/BUILD.md`
- `CHANGELOG.md` → `docs/CHANGELOG.md`
- `DEPLOYMENT.md` → `docs/DEPLOYMENT.md`
- `FEATURES.md` → `docs/FEATURES.md`
- `build*.bat` → `scripts/build*.bat`
- `build.sh` → `scripts/build.sh`
- `run.bat` → `scripts/run.bat`
- `Makefile` → `scripts/Makefile`

### 备份
- `main.go` → `main.go.old` (可以删除)

## 详细文档

更多详细信息请查看：
- [项目结构说明](docs/PROJECT_STRUCTURE.md)
- [构建说明](docs/BUILD.md)
- [部署指南](docs/DEPLOYMENT.md)
