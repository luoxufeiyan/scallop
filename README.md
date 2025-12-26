# Scallop

一个轻量级的网络延迟监控工具，周期性ping指定目标并通过Web界面实时展示延迟数据和历史趋势。

[![GitHub](https://img.shields.io/badge/GitHub-luoxufeiyan%2Fscallop-blue?logo=github)](https://github.com/luoxufeiyan/scallop)
[![Go](https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go)](https://golang.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 特点

- 📊 实时图表展示，支持监测多目标对比分析
- 🎨 深色模式，标签式目标选择
- 💾 SQLite数据持久化，纯Go实现
- 📱 响应式设计，支持移动设备
- 📦 单文件部署，静态资源内嵌

## 快速安装

### Linux 一键安装（推荐）

使用安装脚本自动下载、配置并创建systemd服务：

- 方式1：直接运行

```bash
curl -fsSL https://raw.githubusercontent.com/luoxufeiyan/scallop/master/scripts/install.sh | sudo bash
```

- 方式2：下载后执行

```
wget https://raw.githubusercontent.com/luoxufeiyan/scallop/master/scripts/install.sh
chmod +x install.sh
sudo ./install.sh
```

安装完成后会产生下面文件：
- 二进制文件：`/usr/local/bin/scallop`
- 配置文件：`/etc/scallop/config.json`
- 数据目录：`/var/lib/scallop/ping_data.db`

运行控制：
- 服务管理：`systemctl start/stop/restart scallop`
- 查看日志：`journalctl -u scallop -f`


卸载：
```bash
curl -fsSL https://raw.githubusercontent.com/luoxufeiyan/scallop/master/scripts/uninstall.sh | sudo bash
```

### 手动安装

**1. 下载二进制文件**

从 [Releases](https://github.com/luoxufeiyan/scallop/releases) 下载对应平台的二进制文件，或从 `artifacts/` 目录获取。

**2. 创建配置文件**

创建 `config.json`（参考下方配置说明）。

**3. 运行程序**

```bash
# Linux/macOS
./scallop -config config.json -data ./data

# Windows
scallop.exe -config config.json -data .\data
```

**4. 访问Web界面**

打开浏览器访问：http://localhost:8081

## 配置说明

配置文件 `config.json` 示例：

```json
{
  "title": "Scallop - 网络延迟监控",
  "description": "实时监控网络延迟，支持多目标对比分析",
  "targets": [
    {
      "addr": "8.8.8.8",
      "description": "Google DNS",
      "hide_addr": false,
      "dns_server": ""
    }
  ],
  "ping_interval": 10,
  "web_port": 8081,
  "default_dns": ""
}
```

### 配置项详解

**基础配置**

| 配置项 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| `title` | 可选 | 页面标题，显示在浏览器标签和页面顶部 | `"Scallop - 网络延迟监控"` |
| `description` | 可选 | 页面介绍文字，显示在标题下方 | 空（不显示） |
| `ping_interval` | 必需 | Ping间隔时间（秒），建议 300 | `300` |
| `ping_count`| 必需 | 每次Ping的次数（秒），取值1-10| `4` |
| `web_port` | 必需 | Web服务监听端口，范围 1-65535 | `8081` |
| `default_dns` | 可选 | 默认DNS服务器，用于域名解析 | 空（使用系统DNS） |

**监控目标配置 (targets)**

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `addr` | 必需 | 监控地址，支持IPv4、IPv6或域名 | `"8.8.8.8"`, `"github.com"` |
| `description` | 必需 | 目标描述，显示在界面上 | `"Google DNS"`, `"本地网关"` |
| `hide_addr` | 可选 | 是否隐藏真实地址（隐私保护） | `false` |

### 配置示例

**基础监控**
```json
{
  "targets": [
    {"addr": "8.8.8.8", "description": "Google DNS"},
    {"addr": "114.114.114.114", "description": "114 DNS"}
  ],
  "ping_interval": 10,
  "web_port": 8081
}
```

**隐藏地址**
```json
{
  "targets": [
    {
      "addr": "192.168.1.1",
      "description": "内网网关",
      "hide_addr": true
    }
  ]
}
```

**自定义DNS**
```json
{
  "targets": [
    {
      "addr": "github.com",
      "description": "GitHub",
      "dns_server": "8.8.8.8"
    }
  ],
  "default_dns": "1.1.1.1"
}
```

## 命令行参数

```bash
scallop [选项]

选项：
  -config string
        配置文件路径 (默认 "config.json")
  -data string
        数据目录路径 (默认为当前目录)
```

示例：
```bash
scallop -config /etc/scallop/config.json -data /var/lib/scallop
```


## 使用建议

- Ping间隔建议 10-30 秒
- 监控目标建议不超过 10 个
- 同时显示目标建议 3-5 个，保持图表清晰

## API接口

- `GET /api/targets` - 获取监控目标列表
- `GET /api/status` - 获取最新状态
- `GET /api/config` - 获取配置信息
- `GET /api/ping-data?target_id=<id>&hours=<hours>` - 获取历史数据

## Build

```bash
# 安装依赖
go mod tidy

# 直接运行
go run cmd/scallop/main.go

# 编译
go build -o scallop cmd/scallop/main.go

# 跨平台编译
GOOS=linux GOARCH=amd64 go build -o scallop-linux-amd64 cmd/scallop/main.go
```

详细构建说明参考 [BUILD.md](docs/BUILD.md)
