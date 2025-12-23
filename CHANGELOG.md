# Scallop 更新日志

## [v2.0.0] - 2025-12-23

### 🎉 重大架构升级

#### 📊 全新数据结构
- **目标ID系统**: 每个监控目标现在有唯一的ID，支持更灵活的配置
- **优化数据库**: 分离目标信息和ping结果，提高查询效率
- **实时配置监控**: 自动检测配置文件变化并重新加载

#### 🌐 增强网络支持
- **IPv4/IPv6双栈**: 完整支持IPv4和IPv6地址
- **域名解析**: 支持域名监控，可指定自定义DNS服务器
- **跨平台ping**: 自动检测并使用合适的ping命令

#### 🔒 隐私保护
- **地址隐藏**: 支持隐藏敏感IP地址，只显示描述信息
- **灵活显示**: 可选择性显示或隐藏目标地址

#### ⚙️ 配置增强
```json
{
  "targets": [
    {
      "addr": "8.8.8.8",
      "description": "Google DNS",
      "hide_addr": false
    },
    {
      "addr": "2001:4860:4860::8888", 
      "description": "Google DNS IPv6",
      "hide_addr": false
    },
    {
      "addr": "github.com",
      "description": "GitHub",
      "hide_addr": false,
      "dns_server": "8.8.8.8"
    },
    {
      "addr": "secret.example.com",
      "description": "内部服务",
      "hide_addr": true
    }
  ],
  "ping_interval": 10,
  "web_port": 8081,
  "default_dns": ""
}
```

### 🚀 新功能特性

#### 网络协议支持
- ✅ IPv4地址监控
- ✅ IPv6地址监控  
- ✅ 域名解析监控
- ✅ 自定义DNS服务器
- ✅ 跨平台ping命令

#### 数据管理
- ✅ 目标唯一ID系统
- ✅ 配置文件热重载
- ✅ 数据库结构优化
- ✅ 历史数据保留

#### 用户界面
- ✅ 地址隐藏显示
- ✅ 改进的目标选择
- ✅ 优化的图表标题
- ✅ 更好的错误处理

### 📋 技术改进

#### 后端优化
- **并发安全**: 使用读写锁保护配置访问
- **错误处理**: 完善的错误检测和恢复
- **资源管理**: 优化数据库连接和查询
- **配置验证**: 自动验证和修正配置值

#### 前端增强
- **API更新**: 使用target_id替代addr进行数据查询
- **显示逻辑**: 智能处理地址隐藏显示
- **用户体验**: 改进的加载状态和错误提示

### 🔄 API变更

#### 新增API
- `GET /api/ping-data?target_id=<id>&hours=<hours>` - 使用目标ID查询数据
- 保持向后兼容: `GET /api/ping-data?addr=<addr>&hours=<hours>` - 仍然支持

#### 响应格式更新
```json
{
  "target_id": "a1b2c3d4e5f6g7h8",
  "addr": "8.8.8.8", // 如果hide_addr为true则为空
  "description": "Google DNS",
  "latency": 25.5,
  "success": true,
  "timestamp": "2025-12-23T09:30:00Z"
}
```

### 🛠️ 迁移指南

#### 配置文件升级
程序会自动检测并转换旧格式配置文件：

**旧格式:**
```json
[
  {"addr": "8.8.8.8", "description": "Google DNS"}
]
```

**新格式:**
```json
{
  "targets": [
    {"addr": "8.8.8.8", "description": "Google DNS", "hide_addr": false}
  ],
  "ping_interval": 10,
  "web_port": 8081
}
```

#### 数据库升级
- 新安装会自动使用新的数据库结构
- 旧数据库会被保留但不会自动迁移
- 建议重新开始收集数据以获得最佳体验

### 🐛 修复的问题

- ✅ 修复IPv6地址ping失败问题
- ✅ 修复域名解析超时问题  
- ✅ 修复配置文件锁定问题
- ✅ 修复并发数据库访问问题
- ✅ 修复前端显示异常问题

### 🎯 下一版本计划

- [ ] 添加ping超时配置
- [ ] 支持ICMP和TCP ping模式选择
- [ ] 添加告警功能
- [ ] 支持数据导出
- [ ] 添加性能统计面板

---

## [v1.0.0] - 2025-12-22

### 🎉 首次发布

#### 基础功能
- ✅ 基本ping监控
- ✅ Web可视化界面
- ✅ SQLite数据存储
- ✅ 双模式图表显示
- ✅ 跨平台构建脚本

---

## 贡献者

感谢所有为Scallop项目做出贡献的开发者！

## 许可证

本项目采用 [MIT License](LICENSE) 开源许可证。