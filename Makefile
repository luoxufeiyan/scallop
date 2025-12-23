# Scallop Makefile
# GitHub: https://github.com/luoxufeiyan/scallop

VERSION ?= v1.0.0
BINARY_NAME = scallop
BUILD_DIR = dist
LDFLAGS = -s -w

# 颜色定义
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
CYAN = \033[0;36m
NC = \033[0m # No Color

# 默认目标
.PHONY: all
all: clean build package

# 显示帮助信息
.PHONY: help
help:
	@echo "$(CYAN)Scallop 构建系统$(NC)"
	@echo "$(BLUE)GitHub: https://github.com/luoxufeiyan/scallop$(NC)"
	@echo ""
	@echo "$(YELLOW)可用目标:$(NC)"
	@echo "  $(GREEN)build$(NC)     - 编译所有平台"
	@echo "  $(GREEN)package$(NC)   - 打包所有版本"
	@echo "  $(GREEN)clean$(NC)     - 清理构建文件"
	@echo "  $(GREEN)test$(NC)      - 运行测试"
	@echo "  $(GREEN)dev$(NC)       - 开发模式运行"
	@echo "  $(GREEN)install$(NC)   - 安装到系统"
	@echo ""
	@echo "$(YELLOW)平台特定目标:$(NC)"
	@echo "  $(GREEN)windows$(NC)   - 只编译 Windows 版本"
	@echo "  $(GREEN)linux$(NC)     - 只编译 Linux 版本"
	@echo "  $(GREEN)darwin$(NC)    - 只编译 macOS 版本"
	@echo "  $(GREEN)freebsd$(NC)   - 只编译 FreeBSD 版本"
	@echo ""
	@echo "$(YELLOW)变量:$(NC)"
	@echo "  $(GREEN)VERSION$(NC)   - 版本号 (默认: $(VERSION))"
	@echo ""
	@echo "$(YELLOW)示例:$(NC)"
	@echo "  make build VERSION=v1.1.0"
	@echo "  make windows"
	@echo "  make package"

# 创建构建目录
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# 清理构建文件
.PHONY: clean
clean:
	@echo "$(YELLOW)清理构建文件...$(NC)"
	@rm -rf $(BUILD_DIR)
	@echo "$(GREEN)✓ 清理完成$(NC)"

# 编译所有平台
.PHONY: build
build: $(BUILD_DIR)
	@echo "$(CYAN)========================================$(NC)"
	@echo "$(YELLOW)Scallop 交叉编译$(NC)"
	@echo "$(BLUE)版本: $(VERSION)$(NC)"
	@echo "$(CYAN)========================================$(NC)"
	@echo ""
	@$(MAKE) --no-print-directory build-windows
	@$(MAKE) --no-print-directory build-linux
	@$(MAKE) --no-print-directory build-darwin
	@$(MAKE) --no-print-directory build-freebsd
	@echo ""
	@echo "$(GREEN)✓ 所有平台编译完成$(NC)"

# Windows 平台
.PHONY: build-windows windows
build-windows windows: $(BUILD_DIR)
	@echo "$(CYAN)编译 Windows 版本...$(NC)"
	@GOOS=windows GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe main.go
	@GOOS=windows GOARCH=386 go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-windows-386.exe main.go
	@echo "$(GREEN)✓ Windows 版本编译完成$(NC)"

# Linux 平台
.PHONY: build-linux linux
build-linux linux: $(BUILD_DIR)
	@echo "$(CYAN)编译 Linux 版本...$(NC)"
	@GOOS=linux GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 main.go
	@GOOS=linux GOARCH=386 go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-linux-386 main.go
	@GOOS=linux GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 main.go
	@GOOS=linux GOARCH=arm go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm main.go
	@echo "$(GREEN)✓ Linux 版本编译完成$(NC)"

# macOS 平台
.PHONY: build-darwin darwin macos
build-darwin darwin macos: $(BUILD_DIR)
	@echo "$(CYAN)编译 macOS 版本...$(NC)"
	@GOOS=darwin GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 main.go
	@GOOS=darwin GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 main.go
	@echo "$(GREEN)✓ macOS 版本编译完成$(NC)"

# FreeBSD 平台
.PHONY: build-freebsd freebsd
build-freebsd freebsd: $(BUILD_DIR)
	@echo "$(CYAN)编译 FreeBSD 版本...$(NC)"
	@GOOS=freebsd GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-freebsd-amd64 main.go
	@echo "$(GREEN)✓ FreeBSD 版本编译完成$(NC)"

# 打包所有版本
.PHONY: package
package: build
	@echo ""
	@echo "$(CYAN)开始打包...$(NC)"
	@cd $(BUILD_DIR) && \
	mkdir -p temp && \
	cp ../config.example.json temp/ && \
	cp ../README.md temp/ && \
	cp ../LICENSE temp/ && \
	echo "$(YELLOW)打包 Windows 版本...$(NC)" && \
	cp $(BINARY_NAME)-windows-amd64.exe temp/$(BINARY_NAME).exe && \
	zip -r $(BINARY_NAME)-$(VERSION)-windows-amd64.zip temp/ >/dev/null && \
	rm temp/$(BINARY_NAME).exe && \
	cp $(BINARY_NAME)-windows-386.exe temp/$(BINARY_NAME).exe && \
	zip -r $(BINARY_NAME)-$(VERSION)-windows-386.zip temp/ >/dev/null && \
	rm temp/$(BINARY_NAME).exe && \
	echo "$(YELLOW)打包 Linux 版本...$(NC)" && \
	cp $(BINARY_NAME)-linux-amd64 temp/$(BINARY_NAME) && \
	tar -czf $(BINARY_NAME)-$(VERSION)-linux-amd64.tar.gz -C temp . && \
	rm temp/$(BINARY_NAME) && \
	cp $(BINARY_NAME)-linux-386 temp/$(BINARY_NAME) && \
	tar -czf $(BINARY_NAME)-$(VERSION)-linux-386.tar.gz -C temp . && \
	rm temp/$(BINARY_NAME) && \
	cp $(BINARY_NAME)-linux-arm64 temp/$(BINARY_NAME) && \
	tar -czf $(BINARY_NAME)-$(VERSION)-linux-arm64.tar.gz -C temp . && \
	rm temp/$(BINARY_NAME) && \
	cp $(BINARY_NAME)-linux-arm temp/$(BINARY_NAME) && \
	tar -czf $(BINARY_NAME)-$(VERSION)-linux-arm.tar.gz -C temp . && \
	rm temp/$(BINARY_NAME) && \
	echo "$(YELLOW)打包 macOS 版本...$(NC)" && \
	cp $(BINARY_NAME)-darwin-amd64 temp/$(BINARY_NAME) && \
	tar -czf $(BINARY_NAME)-$(VERSION)-darwin-amd64.tar.gz -C temp . && \
	rm temp/$(BINARY_NAME) && \
	cp $(BINARY_NAME)-darwin-arm64 temp/$(BINARY_NAME) && \
	tar -czf $(BINARY_NAME)-$(VERSION)-darwin-arm64.tar.gz -C temp . && \
	rm temp/$(BINARY_NAME) && \
	echo "$(YELLOW)打包 FreeBSD 版本...$(NC)" && \
	cp $(BINARY_NAME)-freebsd-amd64 temp/$(BINARY_NAME) && \
	tar -czf $(BINARY_NAME)-$(VERSION)-freebsd-amd64.tar.gz -C temp . && \
	rm temp/$(BINARY_NAME) && \
	rm -rf temp && \
	echo "$(YELLOW)生成校验和...$(NC)" && \
	sha256sum *.tar.gz *.zip > $(BINARY_NAME)-$(VERSION)-checksums.txt 2>/dev/null || \
	shasum -a 256 *.tar.gz *.zip > $(BINARY_NAME)-$(VERSION)-checksums.txt 2>/dev/null
	@echo ""
	@echo "$(GREEN)✓ 打包完成$(NC)"
	@echo ""
	@echo "$(YELLOW)生成的文件:$(NC)"
	@cd $(BUILD_DIR) && ls -la *.tar.gz *.zip *.txt 2>/dev/null | awk '{print "  " $$9 " (" $$5 " bytes)"}'

# 运行测试
.PHONY: test
test:
	@echo "$(CYAN)运行测试...$(NC)"
	@go test -v ./...
	@echo "$(GREEN)✓ 测试完成$(NC)"

# 开发模式运行
.PHONY: dev
dev:
	@echo "$(CYAN)启动开发模式...$(NC)"
	@go run main.go

# 安装到系统
.PHONY: install
install:
	@echo "$(CYAN)安装 Scallop...$(NC)"
	@go build -ldflags "$(LDFLAGS)" -o $(BINARY_NAME) main.go
	@sudo mv $(BINARY_NAME) /usr/local/bin/
	@echo "$(GREEN)✓ 安装完成: /usr/local/bin/$(BINARY_NAME)$(NC)"

# 卸载
.PHONY: uninstall
uninstall:
	@echo "$(CYAN)卸载 Scallop...$(NC)"
	@sudo rm -f /usr/local/bin/$(BINARY_NAME)
	@echo "$(GREEN)✓ 卸载完成$(NC)"

# 显示版本信息
.PHONY: version
version:
	@echo "$(CYAN)Scallop 构建系统$(NC)"
	@echo "版本: $(VERSION)"
	@echo "Go 版本: $(shell go version)"

# 检查依赖
.PHONY: deps
deps:
	@echo "$(CYAN)检查依赖...$(NC)"
	@go mod tidy
	@go mod verify
	@echo "$(GREEN)✓ 依赖检查完成$(NC)"

# 格式化代码
.PHONY: fmt
fmt:
	@echo "$(CYAN)格式化代码...$(NC)"
	@go fmt ./...
	@echo "$(GREEN)✓ 代码格式化完成$(NC)"

# 代码检查
.PHONY: lint
lint:
	@echo "$(CYAN)代码检查...$(NC)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "$(YELLOW)警告: golangci-lint 未安装，跳过代码检查$(NC)"; \
	fi

# 显示构建信息
.PHONY: info
info:
	@echo "$(CYAN)构建信息:$(NC)"
	@echo "  项目: Scallop"
	@echo "  版本: $(VERSION)"
	@echo "  二进制名称: $(BINARY_NAME)"
	@echo "  构建目录: $(BUILD_DIR)"
	@echo "  编译标志: $(LDFLAGS)"
	@echo "  Go 版本: $(shell go version)"
	@echo "  Git 提交: $(shell git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"