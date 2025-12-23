# Scallop 交叉编译 PowerShell 脚本
param(
    [string]$Version = "v1.0.0",
    [switch]$Clean,
    [switch]$SkipPackaging,
    [string[]]$Platforms = @()
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Scallop Cross-Compilation Script" -ForegroundColor Yellow
Write-Host "GitHub: https://github.com/luoxufeiyan/scallop" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Cyan
Write-Host

Write-Host "Build Version: $Version" -ForegroundColor Green
Write-Host

# Define build targets
$targets = @(
    @{OS="windows"; ARCH="amd64"; Name="Windows 64-bit"},
    @{OS="windows"; ARCH="386"; Name="Windows 32-bit"},
    @{OS="linux"; ARCH="amd64"; Name="Linux 64-bit"},
    @{OS="linux"; ARCH="386"; Name="Linux 32-bit"},
    @{OS="linux"; ARCH="arm64"; Name="Linux ARM64"},
    @{OS="linux"; ARCH="arm"; Name="Linux ARM"},
    @{OS="darwin"; ARCH="amd64"; Name="macOS Intel"},
    @{OS="darwin"; ARCH="arm64"; Name="macOS Apple Silicon"},
    @{OS="freebsd"; ARCH="amd64"; Name="FreeBSD 64-bit"}
)

# Filter targets if specific platforms are specified
if ($Platforms.Count -gt 0) {
    $targets = $targets | Where-Object { $_.OS -in $Platforms }
}

# Create build directory
if (!(Test-Path "artifacts")) {
    New-Item -ItemType Directory -Path "artifacts" | Out-Null
}
Set-Location "artifacts"

# Clean old files
if ($Clean -or (Test-Path "scallop-*")) {
    Write-Host "Cleaning old files..." -ForegroundColor Yellow
    Remove-Item "scallop-*" -Force -ErrorAction SilentlyContinue
    Remove-Item "*.tar.gz" -Force -ErrorAction SilentlyContinue
    Remove-Item "*.zip" -Force -ErrorAction SilentlyContinue
}

Write-Host "Starting cross-compilation..." -ForegroundColor Green
Write-Host

$count = 1
$total = $targets.Count
$failed = @()

foreach ($target in $targets) {
    $progress = @{
        Activity = "Cross-compiling Scallop"
        Status = "Building $($target.Name)"
        PercentComplete = ($count / $total) * 100
    }
    Write-Progress @progress
    
    Write-Host "[$count/$total] Building $($target.Name)..." -ForegroundColor Cyan
    
    # Set environment variables
    $env:GOOS = $target.OS
    $env:GOARCH = $target.ARCH
    
    # Set output filename
    $output = "scallop-$($target.OS)-$($target.ARCH)"
    if ($target.OS -eq "windows") {
        $output += ".exe"
    }
    
    # Build using direct command execution
    try {
        $result = & go build -ldflags="-s -w" -o $output ../cmd/scallop/main.go 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed: $($target.Name)" -ForegroundColor Red
            Write-Host $result -ForegroundColor Red
            $failed += $target.Name
        } else {
            $size = (Get-Item $output).Length
            $sizeStr = if ($size -gt 1MB) { "{0:N1} MB" -f ($size / 1MB) } else { "{0:N0} KB" -f ($size / 1KB) }
            Write-Host "Build successful: $output ($sizeStr)" -ForegroundColor Green
        }
    } catch {
        Write-Host "Build failed: $($target.Name)" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        $failed += $target.Name
    }
    
    $count++
}

Write-Progress -Activity "Cross-compiling Scallop" -Completed

if ($failed.Count -gt 0) {
    Write-Host
    Write-Host "Failed platforms:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host
}

if (!$SkipPackaging) {
    Write-Host
    Write-Host "Starting packaging..." -ForegroundColor Green
    Write-Host
    
    # Create temp directory and copy necessary files
    if (Test-Path "temp") {
        Remove-Item "temp" -Recurse -Force
    }
    New-Item -ItemType Directory -Path "temp" | Out-Null
    
    Copy-Item "../config.example.json" "temp/"
    Copy-Item "../README.md" "temp/"
    Copy-Item "../LICENSE" "temp/"
    
    # Package function
    function Package-Release {
        param($Binary, $Platform, $Arch, $Extension)
        
        if (Test-Path $Binary) {
            $packageName = "scallop-$Version-$Platform-$Arch"
            Copy-Item $Binary "temp/scallop$Extension"
            
            if ($Platform -eq "windows") {
                # Windows uses zip
                Compress-Archive -Path "temp/*" -DestinationPath "$packageName.zip" -Force
                Write-Host "Packaged: $packageName.zip" -ForegroundColor Green
            } else {
                # Other platforms use tar.gz (if tar command is available)
                if (Get-Command tar -ErrorAction SilentlyContinue) {
                    & tar -czf "$packageName.tar.gz" -C temp .
                    Write-Host "Packaged: $packageName.tar.gz" -ForegroundColor Green
                } else {
                    # If no tar, use zip
                    Compress-Archive -Path "temp/*" -DestinationPath "$packageName.zip" -Force
                    Write-Host "Packaged: $packageName.zip (using zip format)" -ForegroundColor Yellow
                }
            }
            
            Remove-Item "temp/scallop$Extension"
        }
    }
    
    # Package all versions
    Write-Host "Packaging Windows versions..." -ForegroundColor Cyan
    Package-Release "scallop-windows-amd64.exe" "windows" "amd64" ".exe"
    Package-Release "scallop-windows-386.exe" "windows" "386" ".exe"
    
    Write-Host "Packaging Linux versions..." -ForegroundColor Cyan
    Package-Release "scallop-linux-amd64" "linux" "amd64" ""
    Package-Release "scallop-linux-386" "linux" "386" ""
    Package-Release "scallop-linux-arm64" "linux" "arm64" ""
    Package-Release "scallop-linux-arm" "linux" "arm" ""
    
    Write-Host "Packaging macOS versions..." -ForegroundColor Cyan
    Package-Release "scallop-darwin-amd64" "darwin" "amd64" ""
    Package-Release "scallop-darwin-arm64" "darwin" "arm64" ""
    
    Write-Host "Packaging FreeBSD versions..." -ForegroundColor Cyan
    Package-Release "scallop-freebsd-amd64" "freebsd" "amd64" ""
    
    # Clean temp files
    Remove-Item "temp" -Recurse -Force
}

Write-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host

# Show generated files
$files = Get-ChildItem -Path "." -Include "*.tar.gz", "*.zip" -File | Sort-Object
if ($files.Count -gt 0) {
    Write-Host "Generated files:" -ForegroundColor Yellow
    foreach ($file in $files) {
        $size = $file.Length
        $sizeStr = if ($size -gt 1MB) { "{0:N1} MB" -f ($size / 1MB) } else { "{0:N0} KB" -f ($size / 1KB) }
        Write-Host "  $($file.Name) ($sizeStr)" -ForegroundColor White
    }
} else {
    Write-Host "No package files found" -ForegroundColor Yellow
}

Write-Host
Write-Host "File location: $(Get-Location)" -ForegroundColor Blue

# Generate checksums
if (!$SkipPackaging -and $files.Count -gt 0) {
    Write-Host
    Write-Host "Generating checksums..." -ForegroundColor Green
    
    $checksumFile = "scallop-$Version-checksums.txt"
    $checksums = @()
    
    foreach ($file in $files) {
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
        $checksums += "$($hash.Hash.ToLower())  $($file.Name)"
    }
    
    $checksums | Out-File -FilePath $checksumFile -Encoding UTF8
    Write-Host "SHA256 checksums saved to: $checksumFile" -ForegroundColor Green
}

Set-Location ".."
Write-Host
Write-Host "Build Complete!" -ForegroundColor Green

# Usage examples
Write-Host
Write-Host "Usage examples:" -ForegroundColor Yellow
Write-Host "  .\build.ps1                          # Build all platforms" -ForegroundColor Gray
Write-Host "  .\build.ps1 -Version v1.1.0          # Specify version" -ForegroundColor Gray
Write-Host "  .\build.ps1 -Platforms windows,linux # Build specific platforms" -ForegroundColor Gray
Write-Host "  .\build.ps1 -Clean                   # Clean before build" -ForegroundColor Gray
Write-Host "  .\build.ps1 -SkipPackaging           # Build only, no packaging" -ForegroundColor Gray