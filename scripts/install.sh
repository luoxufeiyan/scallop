#!/bin/bash

# Scallop 一键安装脚本 (Linux)
# 自动从GitHub下载二进制文件，配置并创建systemd守护进程

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
GITHUB_REPO="luoxufeiyan/scallop"
BINARY_PATH="/usr/local/bin/scallop"
CONFIG_DIR="/etc/scallop"
DATA_DIR="/var/lib/scallop"
SERVICE_NAME="scallop"
SERVICE_USER="scallop"
WEB_PORT=8081

# 打印信息
info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "请使用root权限运行此脚本: sudo $0"
    fi
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            error "不支持的架构: $arch"
            ;;
    esac
}

# 获取最新版本
get_latest_version() {
    info "获取最新版本信息..."
    local version=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
    
    if [ -z "$version" ]; then
        # 如果无法获取版本号，直接使用 latest 标签
        echo "latest"
    else
        echo "$version"
    fi
}

# 下载二进制文件
download_binary() {
    local arch=$(detect_arch)
    local version=$1
    local binary_name="scallop-linux-${arch}"
    local download_url
    
    info "检测到系统架构: linux-${arch}"
    
    # 使用 latest 标签下载最新版本
    download_url="https://github.com/${GITHUB_REPO}/releases/latest/download/${binary_name}"
    info "下载最新版本"
    info "下载地址: ${download_url}"
    
    # 下载文件
    if ! curl -L -o "/tmp/${binary_name}" "${download_url}" 2>&1 | grep -v "^[[:space:]]*$" >&2; then
        error "下载失败，请检查网络连接或GitHub访问"
    fi
    
    info "下载完成"
    echo "/tmp/${binary_name}"
}

# 创建目录和用户
setup_environment() {
    info "创建配置目录: ${CONFIG_DIR}"
    mkdir -p "${CONFIG_DIR}"
    
    info "创建数据目录: ${DATA_DIR}"
    mkdir -p "${DATA_DIR}"
    
    # 创建专用用户（如果不存在）
    if ! id "${SERVICE_USER}" &>/dev/null; then
        info "创建系统用户: ${SERVICE_USER}"
        useradd -r -s /bin/false -d "${DATA_DIR}" "${SERVICE_USER}"
    fi
}

# 安装二进制文件
install_binary() {
    local binary_path=$1
    
    info "安装二进制文件到 ${BINARY_PATH}"
    cp "${binary_path}" "${BINARY_PATH}"
    chmod +x "${BINARY_PATH}"
    
    # 清理临时文件
    rm -f "${binary_path}"
}

# 设置 ping 权限
setup_ping_permissions() {
    info "配置 ping 命令权限"
    
    # 检查并设置 /bin/ping 权限
    if [ -f /bin/ping ]; then
        info "设置 /bin/ping 权限"
        # 先尝试使用 capabilities
        if command -v setcap &> /dev/null; then
            setcap cap_net_raw+p /bin/ping 2>/dev/null && info "已设置 /bin/ping capabilities" || {
                warn "无法设置 capabilities，尝试设置 setuid"
                chmod u+s /bin/ping
            }
        else
            warn "setcap 命令不存在，设置 setuid 权限"
            chmod u+s /bin/ping
        fi
    fi
    
    # 检查并设置 /usr/bin/ping 权限（某些系统 ping 在这里）
    if [ -f /usr/bin/ping ]; then
        info "设置 /usr/bin/ping 权限"
        if command -v setcap &> /dev/null; then
            setcap cap_net_raw+p /usr/bin/ping 2>/dev/null && info "已设置 /usr/bin/ping capabilities" || {
                warn "无法设置 capabilities，尝试设置 setuid"
                chmod u+s /usr/bin/ping
            }
        else
            chmod u+s /usr/bin/ping
        fi
    fi
    
    # 检查并设置 ping6 权限
    if [ -f /bin/ping6 ]; then
        info "设置 /bin/ping6 权限"
        if command -v setcap &> /dev/null; then
            setcap cap_net_raw+p /bin/ping6 2>/dev/null || chmod u+s /bin/ping6
        else
            chmod u+s /bin/ping6
        fi
    fi
    
    if [ -f /usr/bin/ping6 ]; then
        info "设置 /usr/bin/ping6 权限"
        if command -v setcap &> /dev/null; then
            setcap cap_net_raw+p /usr/bin/ping6 2>/dev/null || chmod u+s /usr/bin/ping6
        else
            chmod u+s /usr/bin/ping6
        fi
    fi
}

# 创建默认配置文件
create_config() {
    local config_file="${CONFIG_DIR}/config.json"
    
    if [ -f "${config_file}" ]; then
        warn "配置文件已存在，跳过创建"
        return
    fi
    
    info "创建默认配置文件: ${config_file}"
    cat > "${config_file}" << 'EOF'
{
  "title": "Scallop - 网络延迟监控",
  "description": "实时监控网络延迟，支持多目标对比分析",
  "targets": [
    {
      "addr": "8.8.8.8",
      "description": "Google DNS",
      "hide_addr": false
    },
    {
      "addr": "114.114.114.114",
      "description": "114 DNS",
      "hide_addr": false
    },
    {
      "addr": "1.1.1.1",
      "description": "Cloudflare DNS",
      "hide_addr": false
    }
  ],
  "ping_interval": 10,
  "web_port": 8081,
  "default_dns": ""
}
EOF
    
    chmod 644 "${config_file}"
}

# 创建systemd服务
create_systemd_service() {
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    info "创建systemd服务: ${service_file}"
    cat > "${service_file}" << EOF
[Unit]
Description=Scallop Network Latency Monitor
Documentation=https://github.com/${GITHUB_REPO}
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${DATA_DIR}
ExecStart=${BINARY_PATH} -config ${CONFIG_DIR}/config.json -data ${DATA_DIR}
Restart=on-failure
RestartSec=5s

# 安全设置
# 注意: NoNewPrivileges 会阻止 ping 命令使用 capabilities，所以必须注释掉
# NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${DATA_DIR}

# 资源限制
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    chmod 644 "${service_file}"
}

# 设置文件权限
set_permissions() {
    info "设置文件权限"
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${CONFIG_DIR}"
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${DATA_DIR}"
}

# 启动服务
start_service() {
    info "重载systemd配置"
    systemctl daemon-reload
    
    info "启用并启动 ${SERVICE_NAME} 服务"
    systemctl enable "${SERVICE_NAME}"
    systemctl start "${SERVICE_NAME}"
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        info "服务启动成功！"
        
        # 测试 ping 权限
        info "测试 ping 权限..."
        if sudo -u "${SERVICE_USER}" ping -c 1 8.8.8.8 &>/dev/null; then
            info "Ping 测试成功！"
        else
            warn "Ping 测试失败，请检查日志: journalctl -u ${SERVICE_NAME} -n 50"
        fi
    else
        error "服务启动失败，请检查日志: journalctl -u ${SERVICE_NAME} -n 50"
    fi
}

# 显示安装信息
show_info() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Scallop 安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "二进制文件: ${BINARY_PATH}"
    echo "配置文件: ${CONFIG_DIR}/config.json"
    echo "数据目录: ${DATA_DIR}"
    echo "数据库文件: ${DATA_DIR}/ping_data.db"
    echo "Web访问地址: http://$(hostname -I | awk '{print $1}'):${WEB_PORT}"
    echo ""
    echo "常用命令:"
    echo "  启动服务: systemctl start ${SERVICE_NAME}"
    echo "  停止服务: systemctl stop ${SERVICE_NAME}"
    echo "  重启服务: systemctl restart ${SERVICE_NAME}"
    echo "  查看状态: systemctl status ${SERVICE_NAME}"
    echo "  查看日志: journalctl -u ${SERVICE_NAME} -f"
    echo "  编辑配置: nano ${CONFIG_DIR}/config.json"
    echo ""
    echo "故障排查:"
    echo "  如果 ping 不工作，请检查:"
    echo "  1. 查看服务日志: journalctl -u ${SERVICE_NAME} -n 50"
    echo "  2. 测试 ping 权限: sudo -u ${SERVICE_USER} ping -c 1 8.8.8.8"
    echo "  3. 检查 ping 权限: ls -l /bin/ping && getcap /bin/ping"
    echo "  4. 手动设置权限: sudo setcap cap_net_raw+p /bin/ping"
    echo "  5. 或使用 setuid: sudo chmod u+s /bin/ping"
    echo ""
    echo "修改配置后需要重启服务: systemctl restart ${SERVICE_NAME}"
    echo ""
}

# 主函数
main() {
    info "开始安装 Scallop..."
    
    # 检查权限
    check_root
    
    # 获取版本并下载
    local version=$(get_latest_version)
    local binary_path=$(download_binary "$version")
    
    # 安装
    setup_environment
    install_binary "$binary_path"
    setup_ping_permissions
    create_config
    set_permissions
    create_systemd_service
    start_service
    
    # 显示信息
    show_info
}

# 运行主函数
main
