@echo off
echo 正在启动 Scallop 网络延迟监控器...
echo GitHub: https://github.com/luoxufeiyan/scallop
echo.

REM 设置CGO环境变量
set CGO_ENABLED=1

echo 检查依赖...
go mod tidy
if %errorlevel% neq 0 (
    echo 依赖安装失败！
    pause
    exit /b 1
)

echo 启动监控程序...
echo Web界面将在 http://localhost:8081 启动
go run cmd/scallop/main.go

pause