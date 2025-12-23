@echo off
echo ========================================
echo Scallop 交叉编译脚本
echo GitHub: https://github.com/luoxufeiyan/scallop
echo ========================================
echo.

REM 设置版本号
set VERSION=v1.0.0
if not "%1"=="" set VERSION=%1

echo 编译版本: %VERSION%
echo.

REM 创建构建目录
if not exist "dist" mkdir dist
cd dist

REM 清理旧文件
if exist "*.exe" del /q *.exe
if exist "*.tar.gz" del /q *.tar.gz
if exist "*.zip" del /q *.zip

echo 开始交叉编译...
echo.

REM Windows 64位
echo [1/8] 编译 Windows 64位...
set GOOS=windows
set GOARCH=amd64
go build -ldflags "-s -w" -o scallop-windows-amd64.exe ../main.go
if %errorlevel% neq 0 (
    echo 编译失败: Windows 64位
    goto :error
)

REM Windows 32位
echo [2/8] 编译 Windows 32位...
set GOOS=windows
set GOARCH=386
go build -ldflags "-s -w" -o scallop-windows-386.exe ../main.go
if %errorlevel% neq 0 (
    echo 编译失败: Windows 32位
    goto :error
)

REM Linux 64位
echo [3/8] 编译 Linux 64位...
set GOOS=linux
set GOARCH=amd64
go build -ldflags "-s -w" -o scallop-linux-amd64 ../main.go
if %errorlevel% neq 0 (
    echo 编译失败: Linux 64位
    goto :error
)

REM Linux 32位
echo [4/8] 编译 Linux 32位...
set GOOS=linux
set GOARCH=386
go build -ldflags "-s -w" -o scallop-linux-386 ../main.go
if %errorlevel% neq 0 (
    echo 编译失败: Linux 32位
    goto :error
)

REM Linux ARM64
echo [5/8] 编译 Linux ARM64...
set GOOS=linux
set GOARCH=arm64
go build -ldflags "-s -w" -o scallop-linux-arm64 ../main.go
if %errorlevel% neq 0 (
    echo 编译失败: Linux ARM64
    goto :error
)

REM macOS 64位 (Intel)
echo [6/8] 编译 macOS Intel...
set GOOS=darwin
set GOARCH=amd64
go build -ldflags "-s -w" -o scallop-darwin-amd64 ../main.go
if %errorlevel% neq 0 (
    echo 编译失败: macOS Intel
    goto :error
)

REM macOS ARM64 (Apple Silicon)
echo [7/8] 编译 macOS Apple Silicon...
set GOOS=darwin
set GOARCH=arm64
go build -ldflags "-s -w" -o scallop-darwin-arm64 ../main.go
if %errorlevel% neq 0 (
    echo 编译失败: macOS Apple Silicon
    goto :error
)

REM FreeBSD 64位
echo [8/8] 编译 FreeBSD 64位...
set GOOS=freebsd
set GOARCH=amd64
go build -ldflags "-s -w" -o scallop-freebsd-amd64 ../main.go
if %errorlevel% neq 0 (
    echo 编译失败: FreeBSD 64位
    goto :error
)

echo.
echo 开始打包...
echo.

REM 复制必要文件到临时目录
mkdir temp
copy ..\config.example.json temp\ >nul
copy ..\README.md temp\ >nul
copy ..\LICENSE temp\ >nul

REM 打包 Windows 版本
echo 打包 Windows 版本...
copy scallop-windows-amd64.exe temp\scallop.exe >nul
powershell -command "Compress-Archive -Path temp\* -DestinationPath scallop-%VERSION%-windows-amd64.zip -Force"
del temp\scallop.exe

copy scallop-windows-386.exe temp\scallop.exe >nul
powershell -command "Compress-Archive -Path temp\* -DestinationPath scallop-%VERSION%-windows-386.zip -Force"
del temp\scallop.exe

REM 打包 Linux 版本 (需要tar命令，如果没有则跳过)
where tar >nul 2>nul
if %errorlevel% equ 0 (
    echo 打包 Linux 版本...
    copy scallop-linux-amd64 temp\scallop >nul
    tar -czf scallop-%VERSION%-linux-amd64.tar.gz -C temp .
    del temp\scallop
    
    copy scallop-linux-386 temp\scallop >nul
    tar -czf scallop-%VERSION%-linux-386.tar.gz -C temp .
    del temp\scallop
    
    copy scallop-linux-arm64 temp\scallop >nul
    tar -czf scallop-%VERSION%-linux-arm64.tar.gz -C temp .
    del temp\scallop
) else (
    echo 警告: 未找到tar命令，跳过Linux版本打包
)

REM 打包 macOS 版本
where tar >nul 2>nul
if %errorlevel% equ 0 (
    echo 打包 macOS 版本...
    copy scallop-darwin-amd64 temp\scallop >nul
    tar -czf scallop-%VERSION%-darwin-amd64.tar.gz -C temp .
    del temp\scallop
    
    copy scallop-darwin-arm64 temp\scallop >nul
    tar -czf scallop-%VERSION%-darwin-arm64.tar.gz -C temp .
    del temp\scallop
)

REM 打包 FreeBSD 版本
where tar >nul 2>nul
if %errorlevel% equ 0 (
    echo 打包 FreeBSD 版本...
    copy scallop-freebsd-amd64 temp\scallop >nul
    tar -czf scallop-%VERSION%-freebsd-amd64.tar.gz -C temp .
    del temp\scallop
)

REM 清理临时文件
rmdir /s /q temp

echo.
echo ========================================
echo 编译完成！
echo ========================================
echo.
echo 生成的文件:
dir /b *.exe *.tar.gz *.zip 2>nul
echo.
echo 文件位置: %cd%
echo.

cd ..
goto :end

:error
echo.
echo ========================================
echo 编译失败！
echo ========================================
cd ..
exit /b 1

:end
pause