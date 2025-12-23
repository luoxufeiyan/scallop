# Scallop 更新日志

## [v1.0.0] - 2025-12-22

### 🎉 重大改进

#### 📦 嵌入式资源部署
- **单文件部署**: 所有静态资源（HTML模板、CSS、JavaScript）现已嵌入到二进制文件中
- **简化部署**: 无需单独部署 `templates/` 和 `static/` 目录
- **跨平台兼容**: 解决了Linux环境下"templates找不到"的问题
- **容器友好**: Docker镜像体积更小，部署更简单

#### 🎨 界面优化
- **双模式显示**: 支持单个目标详细分析和多目标聚合对比
- **复选框控制**: 灵活选择要显示的监控目标
- **美观配色**: 改进单个显示模式的图表配色
- **响应式设计**: 完美适配移动设备

#### ⚙️ 配置增强
- **可配置ping间隔**: 支持自定义ping频率（默认10秒）
- **可配置Web端口**: 支持自定义Web服务端口（默认8081）
- **向后兼容**: 自动转换旧格式配置文件

#### 🔧 构建系统
- **多平台构建脚本**: 支持Windows、Linux、macOS等9个平台
- **自动化打包**: 生成压缩包和校验和文件
- **CI/CD集成**: GitHub Actions自动构建和发布
- **Make支持**: 完整的Makefile构建系统

### 🚀 新功能

#### 可视化增强
- **颜色指示器**: 每个目标使用不同颜色区分
- **全选/全不选**: 批量控制目标显示
- **实时图表**: 自动刷新和数据更新
- **时间范围选择**: 支持1小时到7天的数据查看

#### 技术改进
- **纯Go SQLite**: 使用modernc.org/sqlite，无需CGO
- **系统ping**: 使用系统ping命令，无需管理员权限
- **错误处理**: 完善的错误检测和恢复机制
- **性能优化**: 并发ping和数据库连接池

### 📋 支持的平台

| 操作系统 | 架构 | 状态 |
|----------|------|------|
| Windows | amd64, 386 | ✅ 完全支持 |
| Linux | amd64, 386, arm64, arm | ✅ 完全支持 |
| macOS | amd64 (Intel), arm64 (Apple Silicon) | ✅ 完全支持 |
| FreeBSD | amd64 | ✅ 完全支持 |

### 🛠️ 构建工具

- `build-simple.bat` - Windows快速构建
- `build.bat` - Windows完整构建
- `build.ps1` - PowerShell高级构建
- `build.sh` - Unix Shell构建
- `Makefile` - Make构建系统
- GitHub Actions - 自动化CI/CD

### 📚 文档

- `README.md` - 项目介绍和快速开始
- `BUILD.md` - 详细构建指南
- `DEPLOYMENT.md` - 部署和生产环境配置
- `FEATURES.md` - 功能特性说明

### 🔄 迁移指南

#### 从源码运行升级到v1.0.0

**之前的部署方式:**
```bash
# 需要确保templates和static目录存在
./scallop
```

**现在的部署方式:**
```bash
# 单文件部署，无需额外文件
./scallop
```

#### 配置文件升级

**旧格式 (仍然支持):**
```json
[
  {"addr": "8.8.8.8", "description": "Google DNS"}
]
```

**新格式 (推荐):**
```json
{
  "targets": [
    {"addr": "8.8.8.8", "description": "Google DNS"}
  ],
  "ping_interval": 10,
  "web_port": 8081
}
```

### 🐛 修复的问题

- ✅ 修复Linux环境下"templates找不到"的问题
- ✅ 修复单个显示模式图表配色问题
- ✅ 修复并发数据库访问锁定问题
- ✅ 修复跨平台ping命令兼容性问题

### 🎯 下一版本计划

- [ ] 添加邮件/Webhook告警功能
- [ ] 支持自定义ping超时时间
- [ ] 添加数据导出功能
- [ ] 支持更多图表类型
- [ ] 添加性能统计和报告

---

## 贡献者

感谢所有为Scallop项目做出贡献的开发者！

## 许可证

本项目采用 [MIT License](LICENSE) 开源许可证。