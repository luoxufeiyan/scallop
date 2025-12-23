# Scallop 构建指南

本项目提供了多种构建脚本，支持不同平台和使用场景。

## 构建脚本概览

| 脚本 | 平台 | 特性 | 推荐用途 |
|------|------|------|----------|
| `build-simple.bat` | Windows | 简单快速 | 快速构建主要平台 |
| `build.bat` | Windows | 功能完整 | 完整的构建和打包 |
| `build.ps1` | Windows/跨平台 | 高级功能 | 自动化和CI/CD |
| `build.sh` | Linux/macOS | Shell脚本 | Unix环境构建 |
| `Makefile` | Linux/macOS | Make工具 | 开发环境 |

## 快速开始

### Windows 用户

**最简单的方式：**
```cmd
build-simple.bat
```

**完整功能：**
```cmd
build.bat v1.0.0
```

**PowerShell (推荐)：**
```powershell
.\build.ps1 -Version v1.0.0
```

### Linux/macOS 用户

**Shell脚本：**
```bash
chmod +x build.sh
./build.sh v1.0.0
```

**Makefile：**
```bash
make all VERSION=v1.0.0
```

## 详细使用说明

### build-simple.bat (Windows 快速构建)

最简单的构建脚本，构建4个主要平台：
- Windows 64位
- Linux 64位  
- macOS Intel
- macOS Apple Silicon

```cmd
# 使用默认版本
build-simple.bat

# 指定版本
build-simple.bat v1.1.0
```

### build.bat (Windows 完整构建)

功能完整的批处理脚本，支持8个平台并自动打包：

```cmd
# 默认构建
build.bat

# 指定版本
build.bat v1.1.0
```

**支持的平台：**
- Windows (64位/32位)
- Linux (64位/32位/ARM64)
- macOS (Intel/Apple Silicon)
- FreeBSD (64位)

### build.ps1 (PowerShell 高级构建)

最强大的构建脚本，支持参数化配置：

```powershell
# 基本用法
.\build.ps1

# 指定版本
.\build.ps1 -Version v1.1.0

# 只构建特定平台
.\build.ps1 -Platforms windows,linux

# 清理后构建
.\build.ps1 -Clean

# 只编译不打包
.\build.ps1 -SkipPackaging

# 组合使用
.\build.ps1 -Version v1.2.0 -Platforms windows -Clean
```

### build.sh (Unix Shell 脚本)

适用于Linux和macOS的shell脚本：

```bash
# 给脚本执行权限
chmod +x build.sh

# 基本构建
./build.sh

# 指定版本
./build.sh v1.1.0
```

### Makefile (开发环境)

适合开发环境使用的Make构建系统：

```bash
# 查看帮助
make help

# 构建所有平台
make build

# 构建并打包
make all

# 只构建特定平台
make windows
make linux
make darwin

# 指定版本
make build VERSION=v1.1.0

# 开发模式运行
make dev

# 运行测试
make test

# 安装到系统
make install
```

## 构建输出

所有构建脚本都会在 `dist/` 目录下生成文件：

### 二进制文件
- `scallop-windows-amd64.exe`
- `scallop-linux-amd64`
- `scallop-darwin-amd64`
- 等等...

### 打包文件 (如果启用打包)
- `scallop-v1.0.0-windows-amd64.zip`
- `scallop-v1.0.0-linux-amd64.tar.gz`
- `scallop-v1.0.0-darwin-amd64.tar.gz`
- 等等...

**注意**: 从v1.0.0开始，静态资源已嵌入二进制文件，打包文件中只包含：
- 二进制文件 (scallop/scallop.exe)
- 配置示例 (config.example.json)
- 文档文件 (README.md, LICENSE)

### 校验和文件
- `scallop-v1.0.0-checksums.txt` (SHA256校验和)

## 构建要求

### 基本要求
- Go 1.21 或更高版本
- Git (用于版本信息)

### 平台特定要求

**Windows:**
- PowerShell 5.0+ (用于 build.ps1)
- 可选：tar 命令 (用于生成 .tar.gz 文件)

**Linux/macOS:**
- bash shell
- tar 命令
- make 工具 (用于 Makefile)
- 可选：zip 命令

## 故障排除

### 常见问题

**1. "go: command not found"**
- 确保已安装Go并添加到PATH

**2. "Permission denied" (Linux/macOS)**
```bash
chmod +x build.sh
```

**3. PowerShell执行策略错误**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**4. 构建失败**
- 检查Go版本：`go version`
- 清理模块缓存：`go clean -modcache`
- 重新下载依赖：`go mod tidy`

### 调试构建

**启用详细输出：**
```bash
# 在构建命令前添加
export GOOS=linux GOARCH=amd64
go build -v -x -o scallop-test main.go
```

**检查依赖：**
```bash
go mod verify
go mod graph
```

## CI/CD 集成

项目包含 GitHub Actions 工作流 (`.github/workflows/build.yml`)，会在以下情况自动构建：

- 推送标签 (如 `v1.0.0`)
- Pull Request 到 main 分支
- 手动触发

构建产物会自动上传到 GitHub Releases。

## 自定义构建

### 添加新平台

编辑构建脚本，添加新的 GOOS/GOARCH 组合：

```bash
# 例如：添加 RISC-V 支持
GOOS=linux GOARCH=riscv64 go build -o scallop-linux-riscv64 main.go
```

### 修改构建标志

默认使用 `-ldflags="-s -w"` 来减小二进制大小。可以根据需要修改：

```bash
# 保留调试信息
go build -o scallop main.go

# 添加版本信息
go build -ldflags="-X main.version=v1.0.0" -o scallop main.go
```

## 性能优化

### 并行构建

大多数脚本支持并行构建以提高速度。如果遇到问题，可以禁用并行：

```bash
# 设置单线程构建
export GOMAXPROCS=1
```

### 构建缓存

Go会自动缓存构建结果。清理缓存：

```bash
go clean -cache
go clean -modcache
```

## 发布流程

1. 更新版本号
2. 运行完整构建：`make all VERSION=v1.x.x`
3. 测试生成的二进制文件
4. 创建Git标签：`git tag v1.x.x`
5. 推送标签：`git push origin v1.x.x`
6. GitHub Actions会自动创建Release