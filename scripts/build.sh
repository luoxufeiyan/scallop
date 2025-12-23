#!/bin/bash

echo "========================================"
echo "Scallop 交叉编译脚本"
echo "GitHub: https://github.com/luoxufeiyan/scallop"
echo "========================================"
echo

# 设置版本号
VERSION=${1:-v1.0.0}
echo "编译版本: $VERSION"
echo

# 创建构建目录
mkdir -p artifacts
cd artifacts

# 清理旧文件
rm -f scallop-* *.tar.gz *.zip

echo "开始交叉编译..."
echo

# 定义编译目标
declare -a targets=(
    "windows/amd64"
    "windows/386"
    "linux/amd64"
    "linux/386"
    "linux/arm64"
    "linux/arm"
    "darwin/amd64"
    "darwin/arm64"
    "freebsd/amd64"
)

# 编译计数器
count=1
total=${#targets[@]}

# 编译所有目标
for target in "${targets[@]}"; do
    IFS='/' read -r GOOS GOARCH <<< "$target"
    
    echo "[$count/$total] 编译 $GOOS $GOARCH..."
    
    # 设置输出文件名
    output="scallop-$GOOS-$GOARCH"
    if [ "$GOOS" = "windows" ]; then
        output="$output.exe"
    fi
    
    # 编译
    env GOOS=$GOOS GOARCH=$GOARCH go build -ldflags "-s -w" -o "$output" ../cmd/scallop/main.go
    
    if [ $? -ne 0 ]; then
        echo "编译失败: $GOOS $GOARCH"
        exit 1
    fi
    
    ((count++))
done

echo
echo "开始打包..."
echo

# 创建临时目录并复制必要文件
mkdir -p temp
cp ../config.example.json temp/
cp ../README.md temp/
cp ../LICENSE temp/

# 打包函数
package_release() {
    local binary=$1
    local platform=$2
    local arch=$3
    local ext=$4
    
    if [ -f "$binary" ]; then
        cp "$binary" "temp/scallop$ext"
        
        if [ "$platform" = "windows" ]; then
            # Windows 使用 zip
            (cd temp && zip -r "../scallop-$VERSION-$platform-$arch.zip" .)
        else
            # 其他平台使用 tar.gz
            tar -czf "scallop-$VERSION-$platform-$arch.tar.gz" -C temp .
        fi
        
        rm "temp/scallop$ext"
        echo "已打包: scallop-$VERSION-$platform-$arch"
    fi
}

# 打包所有版本
echo "打包 Windows 版本..."
package_release "scallop-windows-amd64.exe" "windows" "amd64" ".exe"
package_release "scallop-windows-386.exe" "windows" "386" ".exe"

echo "打包 Linux 版本..."
package_release "scallop-linux-amd64" "linux" "amd64" ""
package_release "scallop-linux-386" "linux" "386" ""
package_release "scallop-linux-arm64" "linux" "arm64" ""
package_release "scallop-linux-arm" "linux" "arm" ""

echo "打包 macOS 版本..."
package_release "scallop-darwin-amd64" "darwin" "amd64" ""
package_release "scallop-darwin-arm64" "darwin" "arm64" ""

echo "打包 FreeBSD 版本..."
package_release "scallop-freebsd-amd64" "freebsd" "amd64" ""

# 清理临时文件
rm -rf temp

echo
echo "========================================"
echo "编译完成！"
echo "========================================"
echo
echo "生成的文件:"
ls -la *.tar.gz *.zip 2>/dev/null | awk '{print $9, $5}' | column -t
echo
echo "文件位置: $(pwd)"
echo

# 生成校验和文件
echo "生成校验和文件..."
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum *.tar.gz *.zip 2>/dev/null > "scallop-$VERSION-checksums.txt"
    echo "SHA256 校验和已保存到: scallop-$VERSION-checksums.txt"
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 *.tar.gz *.zip 2>/dev/null > "scallop-$VERSION-checksums.txt"
    echo "SHA256 校验和已保存到: scallop-$VERSION-checksums.txt"
fi

cd ..
echo "构建完成！"