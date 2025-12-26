// 全局变量
let chart = null;
let targets = [];
let selectedTargets = new Set();
let currentHours = 1;
let config = {};
let customTimeRange = null; // 存储自定义时间范围 {start: Date, end: Date}

// 预定义的颜色数组
const chartColors = [
    '#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6',
    '#ec4899', '#14b8a6', '#f97316', '#6366f1', '#84cc16'
];

// 主题管理
const ThemeManager = {
    init() {
        const savedTheme = localStorage.getItem('theme') || 'auto';
        this.setTheme(savedTheme);
        this.setupListeners();
    },

    setTheme(theme) {
        localStorage.setItem('theme', theme);
        
        let actualTheme = theme;
        if (theme === 'auto') {
            actualTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
        }
        
        document.documentElement.setAttribute('data-bs-theme', actualTheme);
        this.updateThemeText(theme);
        
        // 更新图表颜色
        if (chart) {
            this.updateChartTheme(actualTheme);
        }
    },

    updateThemeText(theme) {
        const themeText = document.getElementById('theme-text');
        const texts = {
            'light': '浅色',
            'dark': '深色',
            'auto': '跟随系统'
        };
        themeText.textContent = texts[theme] || '主题';
    },

    updateChartTheme(theme) {
        const textColor = theme === 'dark' ? '#e5e7eb' : '#374151';
        const gridColor = theme === 'dark' ? '#374151' : '#e5e7eb';
        
        chart.options.scales.x.ticks.color = textColor;
        chart.options.scales.y.ticks.color = textColor;
        chart.options.scales.x.grid.color = gridColor;
        chart.options.scales.y.grid.color = gridColor;
        chart.options.plugins.legend.labels.color = textColor;
        chart.update('none');
    },

    setupListeners() {
        document.querySelectorAll('[data-theme]').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                this.setTheme(btn.dataset.theme);
            });
        });

        // 监听系统主题变化
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
            if (localStorage.getItem('theme') === 'auto') {
                this.setTheme('auto');
            }
        });
    }
};

// 初始化
document.addEventListener('DOMContentLoaded', async function() {
    ThemeManager.init();
    await loadConfig();
    await loadTargets();
    loadStatus();
    initChart();
    setupEventListeners();
    
    // 定时刷新状态
    setInterval(loadStatus, 10000);
});

// 加载配置
async function loadConfig() {
    try {
        const response = await fetch('/api/config');
        config = await response.json();
        
        // 设置标题
        const title = config.title || 'Scallop - 网络延迟监控';
        document.getElementById('page-title').textContent = title;
        document.getElementById('header-title').textContent = title;
        
        // 设置介绍
        const descElement = document.getElementById('header-description');
        if (config.description) {
            descElement.textContent = config.description;
            descElement.style.display = 'block';
        } else {
            descElement.style.display = 'none';
        }
    } catch (error) {
        console.error('加载配置失败:', error);
    }
}

// 设置事件监听器
function setupEventListeners() {
    // 时间范围选择
    document.querySelectorAll('.time-range-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.time-range-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            
            if (this.dataset.custom === 'true') {
                // 显示自定义时间选择器
                showCustomTimeRange();
            } else {
                // 隐藏自定义时间选择器
                hideCustomTimeRange();
                customTimeRange = null;
                currentHours = parseInt(this.dataset.hours);
                loadChartData();
            }
        });
    });

    // 应用自定义时间范围
    document.getElementById('apply-custom-range').addEventListener('click', applyCustomTimeRange);

    // 折叠按钮
    document.querySelectorAll('.collapse-toggle').forEach(toggle => {
        toggle.addEventListener('click', function() {
            this.classList.toggle('collapsed');
        });
    });
}

// 显示自定义时间选择器
function showCustomTimeRange() {
    const container = document.getElementById('custom-time-range');
    container.classList.add('show');
    
    // 设置默认值：结束时间为当前，开始时间为24小时前
    const now = new Date();
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    // 只在首次打开或值为空时设置默认值
    if (!document.getElementById('start-time').value) {
        document.getElementById('start-time').value = formatDateTimeLocal(yesterday);
    }
    if (!document.getElementById('end-time').value) {
        document.getElementById('end-time').value = formatDateTimeLocal(now);
    }
}

// 隐藏自定义时间选择器
function hideCustomTimeRange() {
    const container = document.getElementById('custom-time-range');
    container.classList.remove('show');
}

// 应用自定义时间范围
function applyCustomTimeRange() {
    const startInput = document.getElementById('start-time').value;
    const endInput = document.getElementById('end-time').value;
    
    if (!startInput || !endInput) {
        showNotification('请选择开始和结束时间', 'warning');
        return;
    }
    
    const startTime = new Date(startInput);
    const endTime = new Date(endInput);
    
    if (startTime >= endTime) {
        showNotification('开始时间必须早于结束时间', 'error');
        return;
    }
    
    // 检查时间范围是否过大（超过30天）
    const daysDiff = (endTime - startTime) / (1000 * 60 * 60 * 24);
    if (daysDiff > 30) {
        showNotification('时间范围不能超过30天', 'warning');
        return;
    }
    
    customTimeRange = {
        start: startTime,
        end: endTime
    };
    
    showNotification('正在加载数据...', 'info');
    loadChartData();
}

// 显示通知消息
function showNotification(message, type = 'info') {
    // 创建通知元素
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <i class="fas ${getNotificationIcon(type)} me-2"></i>
        <span>${message}</span>
    `;
    
    // 添加到页面
    document.body.appendChild(notification);
    
    // 触发动画
    setTimeout(() => notification.classList.add('show'), 10);
    
    // 3秒后移除
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// 获取通知图标
function getNotificationIcon(type) {
    const icons = {
        'info': 'fa-info-circle',
        'success': 'fa-check-circle',
        'warning': 'fa-exclamation-triangle',
        'error': 'fa-times-circle'
    };
    return icons[type] || icons.info;
}

// 格式化日期时间为 datetime-local 输入格式
function formatDateTimeLocal(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    
    return `${year}-${month}-${day}T${hours}:${minutes}`;
}

// 加载目标列表
async function loadTargets() {
    try {
        const response = await fetch('/api/targets');
        targets = await response.json();
        
        generateTargetTags();
        
        // 默认选择前3个目标
        targets.slice(0, Math.min(3, targets.length)).forEach(target => {
            selectedTargets.add(target.id);
        });
        
        updateTargetTagsUI();
        loadChartData();
    } catch (error) {
        console.error('加载目标失败:', error);
    }
}

// 生成目标标签
function generateTargetTags() {
    const container = document.getElementById('target-tags');
    container.innerHTML = '';
    
    targets.forEach((target, index) => {
        const tag = document.createElement('div');
        tag.className = 'target-tag';
        tag.dataset.targetId = target.id;
        
        const color = chartColors[index % chartColors.length];
        const displayAddr = target.hide_addr ? '***' : target.addr;
        
        tag.innerHTML = `
            <div class="color-dot" style="background-color: ${color}"></div>
            <span>${target.description}</span>
            <small class="text-muted ${target.hide_addr ? 'hidden-addr' : ''}">${displayAddr}</small>
        `;
        
        tag.style.color = color;
        
        tag.addEventListener('click', function() {
            toggleTarget(target.id);
        });
        
        container.appendChild(tag);
    });
}

// 切换目标选择
function toggleTarget(targetId) {
    if (selectedTargets.has(targetId)) {
        selectedTargets.delete(targetId);
    } else {
        selectedTargets.add(targetId);
    }
    updateTargetTagsUI();
    loadChartData();
}

// 更新标签UI
function updateTargetTagsUI() {
    document.querySelectorAll('.target-tag').forEach(tag => {
        const targetId = tag.dataset.targetId;
        if (selectedTargets.has(targetId)) {
            tag.classList.add('active');
        } else {
            tag.classList.remove('active');
        }
    });
}

// 加载状态卡片
async function loadStatus() {
    try {
        const response = await fetch('/api/status');
        const statuses = await response.json();
        
        const container = document.getElementById('status-cards');
        container.innerHTML = '';
        
        document.getElementById('status-count').textContent = statuses.length;
        
        statuses.forEach(status => {
            const card = createStatusCard(status);
            container.appendChild(card);
        });
    } catch (error) {
        console.error('加载状态失败:', error);
    }
}

// 创建状态卡片
function createStatusCard(status) {
    const col = document.createElement('div');
    col.className = 'col-md-6 col-lg-4 col-xl-3';
    
    // 判断延迟等级
    let latencyClass = 'offline';
    let latencyLevel = '离线';
    if (status.success) {
        if (status.latency < 50) {
            latencyClass = 'excellent';
            latencyLevel = '优秀';
        } else if (status.latency < 100) {
            latencyClass = 'good';
            latencyLevel = '良好';
        } else if (status.latency < 200) {
            latencyClass = 'fair';
            latencyLevel = '一般';
        } else {
            latencyClass = 'poor';
            latencyLevel = '较差';
        }
    }
    
    const statusIndicator = status.success ? 
        `<span class="status-indicator online"><i class="fas fa-circle-check"></i>在线</span>` :
        `<span class="status-indicator offline"><i class="fas fa-circle-xmark"></i>离线</span>`;
    
    const latencyValue = status.success ? status.latency.toFixed(1) : '--';
    
    const timeText = new Date(status.timestamp).toLocaleString('zh-CN', {
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
    
    // 地址显示和操作按钮
    let addrSection = '';
    if (status.hide_addr) {
        addrSection = `
            <div class="status-card-addr">
                <span class="addr-text">地址已隐藏</span>
                <span class="hidden-icon" title="地址已隐藏">
                    <i class="fas fa-eye-slash"></i>
                </span>
            </div>
        `;
    } else if (status.addr) {
        addrSection = `
            <div class="status-card-addr">
                <span class="addr-text">${status.addr}</span>
                <button class="copy-btn" onclick="copyAddress('${status.addr}', this)" title="复制地址">
                    <i class="fas fa-copy"></i>
                </button>
            </div>
        `;
    }
    
    col.innerHTML = `
        <div class="status-card">
            <div class="card-body">
                <div class="status-card-header">
                    <h6 class="status-card-title">${status.description}</h6>
                    ${statusIndicator}
                </div>
                
                ${addrSection}
                
                <div class="status-metrics">
                    <div class="metric-item">
                        <div class="metric-label">延迟</div>
                        <div class="metric-value ${latencyClass}">
                            ${latencyValue}<span class="metric-unit">ms</span>
                        </div>
                    </div>
                    <div class="metric-item">
                        <div class="metric-label">状态</div>
                        <div class="metric-value ${latencyClass}" style="font-size: 1rem;">
                            ${latencyLevel}
                        </div>
                    </div>
                </div>
                
                <div class="status-timestamp">
                    <i class="far fa-clock"></i>
                    <span>${timeText}</span>
                </div>
            </div>
        </div>
    `;
    
    return col;
}

// 复制地址到剪贴板
function copyAddress(addr, button) {
    navigator.clipboard.writeText(addr).then(() => {
        const icon = button.querySelector('i');
        const originalClass = icon.className;
        
        // 显示复制成功
        icon.className = 'fas fa-check';
        button.classList.add('copied');
        
        // 2秒后恢复
        setTimeout(() => {
            icon.className = originalClass;
            button.classList.remove('copied');
        }, 2000);
    }).catch(err => {
        console.error('复制失败:', err);
        alert('复制失败，请手动复制');
    });
}

// 初始化图表
function initChart() {
    const ctx = document.getElementById('ping-chart').getContext('2d');
    
    const theme = document.documentElement.getAttribute('data-bs-theme');
    const textColor = theme === 'dark' ? '#e5e7eb' : '#374151';
    const gridColor = theme === 'dark' ? '#374151' : '#e5e7eb';
    
    chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: []
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                intersect: false,
                mode: 'index'
            },
            plugins: {
                legend: {
                    display: true,
                    position: 'top',
                    labels: {
                        color: textColor,
                        usePointStyle: true,
                        padding: 15,
                        font: {
                            size: 12
                        }
                    }
                },
                tooltip: {
                    backgroundColor: 'rgba(0, 0, 0, 0.8)',
                    padding: 12,
                    titleFont: {
                        size: 14
                    },
                    bodyFont: {
                        size: 13
                    },
                    callbacks: {
                        label: function(context) {
                            let label = context.dataset.label || '';
                            if (label) {
                                label += ': ';
                            }
                            if (context.parsed.y !== null) {
                                label += context.parsed.y.toFixed(2) + 'ms';
                            }
                            return label;
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: {
                        color: gridColor,
                        drawBorder: false
                    },
                    ticks: {
                        color: textColor,
                        maxRotation: 45,
                        minRotation: 0
                    }
                },
                y: {
                    beginAtZero: true,
                    grid: {
                        color: gridColor,
                        drawBorder: false
                    },
                    ticks: {
                        color: textColor,
                        callback: function(value) {
                            return value + 'ms';
                        }
                    }
                }
            },
            elements: {
                line: {
                    tension: 0.4,
                    borderWidth: 2
                },
                point: {
                    radius: 0,
                    hitRadius: 10,
                    hoverRadius: 5
                }
            }
        }
    });
}

// 加载图表数据
async function loadChartData() {
    if (selectedTargets.size === 0) {
        chart.data.labels = [];
        chart.data.datasets = [];
        chart.update();
        return;
    }
    
    try {
        const dataPromises = Array.from(selectedTargets).map(async (targetId) => {
            let url = `/api/ping-data?target_id=${encodeURIComponent(targetId)}`;
            
            // 使用自定义时间范围或小时数
            if (customTimeRange) {
                const startTime = customTimeRange.start.toISOString();
                const endTime = customTimeRange.end.toISOString();
                url += `&start_time=${encodeURIComponent(startTime)}&end_time=${encodeURIComponent(endTime)}`;
            } else {
                url += `&hours=${currentHours}`;
            }
            
            const response = await fetch(url);
            const data = await response.json();
            const target = targets.find(t => t.id === targetId);
            return { target, data };
        });
        
        const allData = await Promise.all(dataPromises);
        
        // 收集所有时间戳
        const allTimestamps = new Set();
        allData.forEach(({ data }) => {
            data.forEach(item => allTimestamps.add(item.timestamp));
        });
        
        const sortedTimestamps = Array.from(allTimestamps).sort();
        
        // 根据时间范围决定标签格式
        const timeSpan = customTimeRange 
            ? (customTimeRange.end - customTimeRange.start) / (1000 * 60 * 60) 
            : currentHours;
        
        const labels = sortedTimestamps.map(timestamp => {
            const date = new Date(timestamp);
            if (timeSpan <= 24) {
                return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
            } else {
                return date.toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit' });
            }
        });
        
        // 创建数据集
        const datasets = allData.map(({ target, data }, index) => {
            const targetIndex = targets.findIndex(t => t.id === target.id);
            const color = chartColors[targetIndex % chartColors.length];
            
            const dataPoints = sortedTimestamps.map(timestamp => {
                const point = data.find(item => item.timestamp === timestamp);
                return point && point.success ? point.latency : null;
            });
            
            const displayAddr = target.addr && !target.hide_addr ? ` (${target.addr})` : '';
            
            return {
                label: `${target.description}${displayAddr}`,
                data: dataPoints,
                borderColor: color,
                backgroundColor: color + '20',
                spanGaps: true,
                fill: false
            };
        });
        
        chart.data.labels = labels;
        chart.data.datasets = datasets;
        chart.update();
        
    } catch (error) {
        console.error('加载图表数据失败:', error);
    }
}
