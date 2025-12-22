package ping

import (
	"fmt"
	"net"
	"os/exec"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"

	"scallop/internal/models"
)

// Executor Ping执行器
type Executor struct {
	pingCount int
}

// NewExecutor 创建Ping执行器
func NewExecutor(pingCount int) *Executor {
	return &Executor{
		pingCount: pingCount,
	}
}

// Ping 执行ping操作
func (e *Executor) Ping(target *models.Target) (float64, bool) {
	// 解析地址，支持IPv4、IPv6和域名
	addr := target.Addr

	// 如果是域名，先进行DNS解析
	if !isIPAddress(addr) {
		resolvedAddr, err := resolveAddress(addr, target.DNSServer)
		if err != nil {
			fmt.Printf("DNS解析失败 %s: %v\n", addr, err)
			return 0, false
		}
		addr = resolvedAddr
	}

	// 执行多次ping并收集结果
	var latencies []float64
	successCount := 0

	for i := 0; i < e.pingCount; i++ {
		latency, success := singlePing(addr)
		if success {
			latencies = append(latencies, latency)
			successCount++
		}
	}

	// 如果所有ping都失败，返回失败
	if successCount == 0 {
		return 0, false
	}

	// 计算平均延迟
	var sum float64
	for _, latency := range latencies {
		sum += latency
	}
	avgLatency := sum / float64(len(latencies))

	return avgLatency, true
}

// singlePing 执行单次ping
func singlePing(addr string) (float64, bool) {
	start := time.Now()

	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		// Windows ping命令，自动检测IPv4/IPv6
		if strings.Contains(addr, ":") {
			// IPv6
			cmd = exec.Command("ping", "-6", "-n", "1", "-w", "3000", addr)
		} else {
			// IPv4
			cmd = exec.Command("ping", "-4", "-n", "1", "-w", "3000", addr)
		}
	} else {
		// Linux/Mac ping命令
		if strings.Contains(addr, ":") {
			// IPv6
			cmd = exec.Command("ping6", "-c", "1", "-W", "3", addr)
		} else {
			// IPv4
			cmd = exec.Command("ping", "-c", "1", "-W", "3", addr)
		}
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("Ping失败 %s: %v, 输出: %s\n", addr, err, string(output))
		return 0, false
	}

	duration := time.Since(start)

	// 解析ping输出获取延迟
	latency := parsePingOutput(string(output))
	if latency > 0 {
		return latency, true
	}

	// 如果解析失败，使用总耗时作为近似值
	return float64(duration.Milliseconds()), true
}

// isIPAddress 检查是否为IP地址
func isIPAddress(addr string) bool {
	return net.ParseIP(addr) != nil
}

// resolveAddress 解析域名地址
func resolveAddress(hostname, dnsServer string) (string, error) {
	// 如果指定了DNS服务器，使用nslookup或dig
	if dnsServer != "" {
		return resolveWithCustomDNS(hostname, dnsServer)
	}

	// 使用系统默认DNS
	ips, err := net.LookupIP(hostname)
	if err != nil {
		return "", err
	}

	if len(ips) == 0 {
		return "", fmt.Errorf("无法解析域名: %s", hostname)
	}

	// 优先返回IPv4地址
	for _, ip := range ips {
		if ip.To4() != nil {
			return ip.String(), nil
		}
	}

	// 如果没有IPv4，返回IPv6
	return ips[0].String(), nil
}

// resolveWithCustomDNS 使用自定义DNS服务器解析域名
func resolveWithCustomDNS(hostname, dnsServer string) (string, error) {
	var cmd *exec.Cmd

	if runtime.GOOS == "windows" {
		// Windows使用nslookup
		cmd = exec.Command("nslookup", hostname, dnsServer)
	} else {
		// Linux/Mac优先使用dig，如果没有则使用nslookup
		if _, err := exec.LookPath("dig"); err == nil {
			cmd = exec.Command("dig", "+short", "@"+dnsServer, hostname)
		} else {
			cmd = exec.Command("nslookup", hostname, dnsServer)
		}
	}

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	return parseResolveOutput(string(output))
}

// parseResolveOutput 解析DNS查询输出
func parseResolveOutput(output string) (string, error) {
	lines := strings.Split(output, "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// 检查是否为IP地址
		if net.ParseIP(line) != nil {
			return line, nil
		}

		// 解析nslookup输出
		if strings.Contains(line, "Address:") && !strings.Contains(line, "#") {
			parts := strings.Split(line, ":")
			if len(parts) >= 2 {
				ip := strings.TrimSpace(parts[1])
				if net.ParseIP(ip) != nil {
					return ip, nil
				}
			}
		}
	}

	return "", fmt.Errorf("无法从DNS输出中解析IP地址")
}

// parsePingOutput 解析ping输出
func parsePingOutput(output string) float64 {
	if runtime.GOOS == "windows" {
		// Windows ping输出格式: "时间<1ms" 或 "time<1ms" 或 "时间=1ms"
		re := regexp.MustCompile(`(?i)时间[=<](\d+)ms|time[=<](\d+)ms`)
		matches := re.FindStringSubmatch(output)
		if len(matches) > 1 {
			for i := 1; i < len(matches); i++ {
				if matches[i] != "" {
					if latency, err := strconv.ParseFloat(matches[i], 64); err == nil {
						return latency
					}
				}
			}
		}

		// 如果是 "<1ms" 的情况，返回1ms
		if strings.Contains(output, "时间<1ms") || strings.Contains(output, "time<1ms") {
			return 1.0
		}
	} else {
		// Linux/Mac ping输出格式: "time=1.234 ms"
		re := regexp.MustCompile(`time=([0-9.]+)\s*ms`)
		matches := re.FindStringSubmatch(output)
		if len(matches) > 1 {
			if latency, err := strconv.ParseFloat(matches[1], 64); err == nil {
				return latency
			}
		}
	}

	return 0
}
