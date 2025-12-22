#!/bin/bash

# Scallop 卸载脚本 (Linux)
# 停止服务、删除文件和用户

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
BINARY_PATH="/usr/local/bin/scallop"
CONFIG_DIR="/etc/scallop"
DATA_DIR="/var/lib/scallop"
SERVICE_NAME="scallop"
SERVICE_USER="scallop"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

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

# 停止并禁用服务
stop_service() {
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        info "停止 ${SERVICE_NAME} 服务"
        systemctl stop "${SERVICE_NAME}"
    fi
    
    if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
        info "禁用 ${SERVICE_NAME} 服务"
        systemctl disable "${SERVICE_NAME}"
    fi
}

# 删除systemd服务文件
remove_service() {
    if [ -f "${SERVICE_FILE}" ]; then
        info "删除systemd服务文件: ${SERVICE_FILE}"
        rm -f "${SERVICE_FILE}"
        systemctl daemon-reload
    fi
}

# 删除二进制文件
remove_binary() {
    if [ -f "${BINARY_PATH}" ]; then
        info "删除二进制文件: ${BINARY_PATH}"
        rm -f "${BINARY_PATH}"
    fi
}

# 删除配置和数据
remove_data() {
    local keep_data=false
    
    # 询问是否保留数据
    echo ""
    read -p "是否保留配置文件和数据库？(y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        keep_data=true
        warn "保留配置目录: ${CONFIG_DIR}"
        warn "保留数据目录: ${DATA_DIR}"
    else
        if [ -d "${CONFIG_DIR}" ]; then
            info "删除配置目录: ${CONFIG_DIR}"
            rm -rf "${CONFIG_DIR}"
        fi
        
        if [ -d "${DATA_DIR}" ]; then
            info "删除数据目录: ${DATA_DIR}"
            rm -rf "${DATA_DIR}"
        fi
    fi
}

# 删除系统用户
remove_user() {
    if id "${SERVICE_USER}" &>/dev/null; then
        info "删除系统用户: ${SERVICE_USER}"
        userdel "${SERVICE_USER}" 2>/dev/null || warn "无法删除用户 ${SERVICE_USER}"
    fi
}

# 显示卸载信息
show_info() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Scallop 卸载完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    info "所有 Scallop 组件已被移除"
    echo ""
}

# 主函数
main() {
    info "开始卸载 Scallop..."
    
    # 检查权限
    check_root
    
    # 确认卸载
    echo ""
    echo -e "${YELLOW}警告: 此操作将卸载 Scallop 及其所有组件${NC}"
    read -p "确定要继续吗？(y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "取消卸载"
        exit 0
    fi
    
    # 执行卸载
    stop_service
    remove_service
    remove_binary
    remove_data
    remove_user
    
    # 显示信息
    show_info
}

# 运行主函数
main
