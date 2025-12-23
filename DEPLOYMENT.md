# Scallop 部署指南

## 快速部署

### 1. 下载源码
```bash
git clone https://github.com/luoxufeiyan/scallop.git
cd scallop
```

### 2. 安装依赖
```bash
go mod tidy
```

### 3. 配置监控目标
编辑 `config.json` 文件，或参考 `config.example.json`：
```json
{
  "targets": [
    {
      "addr": "8.8.8.8",
      "description": "Google DNS"
    }
  ],
  "ping_interval": 10,
  "web_port": 8081
}
```

### 4. 启动服务
```bash
# 直接运行
go run main.go

# 或编译后运行 (推荐)
go build -o scallop
./scallop

# Windows
go build -o scallop.exe
scallop.exe
```

**注意**: 从v1.0.0开始，所有静态资源（HTML模板、CSS、JS文件）都已嵌入到二进制文件中，无需单独部署这些文件。

### 5. 访问界面
打开浏览器访问：http://localhost:8081

## 交叉编译

Scallop 提供了多种交叉编译脚本，支持主流平台：

### Windows 批处理脚本
```cmd
# 编译所有平台
build.bat

# 指定版本号
build.bat v1.1.0
```

### PowerShell 脚本 (推荐)
```powershell
# 编译所有平台
.\build.ps1

# 指定版本号
.\build.ps1 -Version v1.1.0

# 只编译特定平台
.\build.ps1 -Platforms windows,linux

# 清理后编译
.\build.ps1 -Clean

# 只编译不打包
.\build.ps1 -SkipPackaging
```

### Shell 脚本 (Linux/macOS)
```bash
# 编译所有平台
chmod +x build.sh
./build.sh

# 指定版本号
./build.sh v1.1.0
```

### Makefile (Linux/macOS)
```bash
# 查看帮助
make help

# 编译所有平台
make build

# 编译并打包
make all

# 只编译特定平台
make windows
make linux
make darwin
make freebsd

# 指定版本号
make build VERSION=v1.1.0

# 开发模式运行
make dev

# 安装到系统
make install
```

### 支持的平台

| 平台 | 架构 | 文件名 |
|------|------|--------|
| Windows | amd64 | scallop-windows-amd64.exe |
| Windows | 386 | scallop-windows-386.exe |
| Linux | amd64 | scallop-linux-amd64 |
| Linux | 386 | scallop-linux-386 |
| Linux | arm64 | scallop-linux-arm64 |
| Linux | arm | scallop-linux-arm |
| macOS | amd64 | scallop-darwin-amd64 |
| macOS | arm64 | scallop-darwin-arm64 |
| FreeBSD | amd64 | scallop-freebsd-amd64 |

## Docker 部署

### 创建 Dockerfile
```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o scallop main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/scallop .
COPY --from=builder /app/config.example.json ./config.json

EXPOSE 8081
CMD ["./scallop"]
```

### 构建和运行
```bash
docker build -t scallop .
docker run -p 8081:8081 -v $(pwd)/config.json:/root/config.json scallop
```

## 生产环境部署

### 1. 使用 systemd 服务
创建 `/etc/systemd/system/scallop.service`：
```ini
[Unit]
Description=Scallop Network Latency Monitor
After=network.target

[Service]
Type=simple
User=scallop
WorkingDirectory=/opt/scallop
ExecStart=/opt/scallop/scallop
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 2. 启动服务
```bash
sudo systemctl enable scallop
sudo systemctl start scallop
sudo systemctl status scallop
```

### 3. 反向代理 (Nginx)
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 配置说明

### 环境变量
- `SCALLOP_CONFIG`: 配置文件路径 (默认: ./config.json)
- `SCALLOP_DB`: 数据库文件路径 (默认: ./ping_data.db)

### 性能调优
- 建议ping间隔设置为10-30秒
- 监控目标数量建议控制在20个以内
- 定期清理历史数据以控制数据库大小

### 安全建议
- 使用反向代理并配置HTTPS
- 限制Web界面的访问IP范围
- 定期备份配置文件和数据库