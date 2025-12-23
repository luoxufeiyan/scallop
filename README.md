# Scallop

一个用Go语言编写的网络延迟监控工具，可以周期性地ping指定的IP地址，并通过Web界面实时展示延迟数据。

[![GitHub](https://img.shields.io/badge/GitHub-luoxufeiyan%2Fscallop-blue?logo=github)](https://github.com/luoxufeiyan/scallop)
[![Go](https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go)](https://golang.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 项目特色

🚀 **简单易用** - 一键启动，Web界面直观友好  
📊 **双模式显示** - 支持单个目标详细分析和多目标对比  
💾 **数据持久化** - 使用SQLite存储历史数据  
🎨 **美观界面** - 响应式设计，支持移动设备  
⚙️ **灵活配置** - 可配置ping间隔、监控目标和Web端口  
🔧 **纯Go实现** - 无CGO依赖，跨平台编译简单  
📦 **单文件部署** - 静态资源嵌入，无需额外文件

## 功能特性

- 🚀 周期性ping监控（默认10秒间隔）
- 📊 实时可视化图表展示
- 💾 SQLite数据持久化（使用纯Go实现，无需CGO）
- 🌐 Web界面管理
- ⚡ 实时状态更新
- 📱 响应式设计

## 快速开始

### 1. 安装依赖

```bash
go mod tidy
```

### 2. 配置监控目标

编辑 `config.json` 文件，配置监控参数。如果文件不存在，程序会自动创建默认配置。

你也可以参考 `config.example.json` 示例文件：

```json
{
  "targets": [
    {
      "addr": "8.8.8.8",
      "description": "Google DNS"
    },
    {
      "addr": "114.114.114.114", 
      "description": "114 DNS"
    }
  ],
  "ping_interval": 10,
  "web_port": 8081
}
```

**配置说明：**
- `targets`: 监控目标列表
  - `addr`: IP地址或域名
  - `description`: 描述信息
- `ping_interval`: ping间隔时间（秒），默认10秒
- `web_port`: Web服务端口，默认8081

### 3. 运行程序

**方式1：使用批处理文件（推荐）**
```bash
run.bat
```

**方式2：使用构建脚本**
```bash
# Windows 快速构建
build-simple.bat

# Windows 完整构建
build.bat v1.0.0

# PowerShell (推荐)
.\build.ps1 -Version v1.0.0

# Linux/macOS
chmod +x build.sh && ./build.sh v1.0.0

# 使用 Make
make all VERSION=v1.0.0
```

**方式3：直接运行**
```bash
go run main.go
```

**方式4：编译后运行**
```bash
go build -o scallop.exe
scallop.exe
```

### 4. 访问Web界面

打开浏览器访问：http://localhost:8081 （端口可在config.json中配置）

## 构建和部署

详细的构建和部署说明请参考：
- [BUILD.md](BUILD.md) - 构建脚本使用指南
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署和生产环境配置

## 使用技巧
### 图表模式选择
- **单个显示**：适合详细分析单个目标的延迟变化趋势

- **聚合显示**：适合对比多个目标的性能，快速识别问题目标

### 最佳实践
- 建议ping间隔设置在10-30秒之间，避免过于频繁
- 长期监控建议查看24小时或7天的数据趋势
- 使用聚合显示对比不同DNS服务器的性能
- 关注延迟突增的时间点，可能对应网络问题

### 性能优化
- 监控目标数量建议控制在10个以内
- 聚合显示同时选择的目标建议不超过5个，以保持图表清晰

### Web界面功能

**状态卡片**
- 显示每个监控目标的当前状态、延迟和最后更新时间
- 实时更新，每10秒刷新一次
- 颜色指示器：绿色边框表示正常，红色边框表示失败

**图表显示模式**

1. **单个显示模式**
   - 选择单个监控目标查看详细延迟趋势
   - 显示填充区域图，便于观察延迟变化
   - 适合深入分析单个目标的网络状况

2. **聚合显示模式**
   - 使用复选框选择多个监控目标
   - 多条线图对比显示，每个目标使用不同颜色
   - 支持全选/全不选功能
   - 适合对比分析多个目标的性能差异

**交互功能**
- 时间范围选择：1小时、6小时、24小时、7天
- 实时数据刷新
- 响应式设计，支持移动设备访问

### 配置文件

`config.json` 包含所有配置选项：

**targets** - 监控目标列表
- `addr`: IP地址或域名
- `description`: 描述信息

**ping_interval** - ping间隔时间（秒）
- 默认值：10秒
- 建议范围：5-60秒
- 设置过小可能影响网络性能

**web_port** - Web服务端口
- 默认值：8081
- 范围：1-65535
- 确保端口未被占用

### 数据存储

程序使用SQLite数据库存储ping结果，数据库文件为 `ping_data.db`。

## API接口

- `GET /api/targets` - 获取监控目标列表
- `GET /api/status` - 获取最新状态
- `GET /api/config` - 获取配置信息（ping间隔、端口等）
- `GET /api/ping-data?addr=<ip>&hours=<hours>` - 获取指定时间范围的ping数据

## 技术栈

- **后端**: Go + Gin + SQLite (modernc.org/sqlite - 纯Go实现)
- **前端**: HTML + JavaScript + Chart.js + Bootstrap (嵌入式资源)
- **网络**: 系统ping命令（跨平台兼容）
- **部署**: 单文件二进制，包含所有静态资源

## 技术说明

### SQLite实现

本项目使用 `modernc.org/sqlite`，这是一个纯Go实现的SQLite驱动，优点：
- 无需CGO支持
- 跨平台编译更简单
- 无需安装C编译器
- 性能接近原生SQLite

### Ping实现

使用系统的ping命令而不是原始ICMP包，优点：
- 无需管理员权限
- 跨平台兼容（Windows/Linux/Mac）
- 更稳定可靠

## 常见问题

### Q: 如何修改ping间隔？
A: 在config.json中修改`ping_interval`字段，单位为秒。建议设置在5-60秒之间。

### Q: 如何修改Web服务端口？
A: 在config.json中修改`web_port`字段，重启程序后生效。

### Q: 程序启动后卡住？
A: 检查配置的端口是否被占用，可以在config.json中修改端口号。

### Q: 如何添加更多监控目标？
A: 编辑config.json文件，添加新的IP地址和描述，重启程序即可。

### Q: 数据库文件在哪里？
A: 在程序运行目录下的`ping_data.db`文件。

## 项目结构

```
scallop/
├── main.go              # 主程序文件
├── go.mod               # Go模块文件
├── config.json          # 监控配置文件
├── config.example.json  # 配置示例文件
├── run.bat              # Windows启动脚本
├── README.md            # 项目说明
├── ping_data.db         # SQLite数据库（运行后生成）
├── templates/
│   └── index.html       # Web界面模板
└── static/
    └── app.js           # 前端JavaScript代码
```