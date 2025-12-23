@echo off
echo ========================================
echo Scallop Simple Build Script
echo ========================================
echo.

set VERSION=%1
if "%VERSION%"=="" set VERSION=v1.0.0

echo Building version: %VERSION%
echo.

REM Create dist directory
if not exist "dist" mkdir dist
cd dist

REM Clean old files
del /q scallop-* 2>nul

echo Building binaries...
echo.

REM Windows 64-bit
echo [1/4] Building Windows 64-bit...
set GOOS=windows
set GOARCH=amd64
go build -ldflags="-s -w" -o scallop-windows-amd64.exe ../main.go
if %errorlevel% neq 0 goto :error

REM Linux 64-bit
echo [2/4] Building Linux 64-bit...
set GOOS=linux
set GOARCH=amd64
go build -ldflags="-s -w" -o scallop-linux-amd64 ../main.go
if %errorlevel% neq 0 goto :error

REM macOS Intel
echo [3/4] Building macOS Intel...
set GOOS=darwin
set GOARCH=amd64
go build -ldflags="-s -w" -o scallop-darwin-amd64 ../main.go
if %errorlevel% neq 0 goto :error

REM macOS Apple Silicon
echo [4/4] Building macOS Apple Silicon...
set GOOS=darwin
set GOARCH=arm64
go build -ldflags="-s -w" -o scallop-darwin-arm64 ../main.go
if %errorlevel% neq 0 goto :error

echo.
echo Build completed successfully!
echo.
echo Generated files:
dir /b scallop-*
echo.
echo Files are located in: %cd%

cd ..
goto :end

:error
echo.
echo Build failed!
cd ..
exit /b 1

:end