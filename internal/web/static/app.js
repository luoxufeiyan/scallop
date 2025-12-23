let chart = null;
let targets = [];
let currentMode = 'single'; // 'single' 或 'multi'

// 预定义的颜色数组，用于多目标显示
const chartColors = [
    'rgb(54, 162, 235)',   // 蓝色
    'rgb(255, 99, 132)',   // 红色
    'rgb(75, 192, 192)',   // 青色
    'rgb(153, 102, 255)',  // 紫色
    'rgb(255, 159, 64)',   // 橙色
    'rgb(255, 205, 86)',   // 黄色
    'rgb(83, 102, 147)',   // 深蓝色
    'rgb(46, 204, 113)',   // 绿色
    'rgb(231, 76, 60)',    // 深红色
    'rgb(142, 68, 173)'    // 深紫色
];

// 单个模式专用的渐变色配置
const singleModeColors = {
    primary: 'rgb(54, 162, 235)',      // 主色调：蓝色
    gradient: 'rgba(54, 162, 235, 0.1)', // 渐变背景：浅蓝色
    success: 'rgb(46, 204, 113)',       // 成功状态：绿色
    warning: 'rgb(255, 193, 7)',        // 警告状态：黄色
    danger: 'rgb(220, 53, 69)'          // 危险状态：红色
};

// 初始化
document.addEventListener('DOMContentLoaded', function() {
    loadTargets();
    loadStatus();
    initChart();
    setupEventListeners();
    
    // 设置定时刷新
    setInterval(loadStatus, 10000); // 每10秒刷新状态
});

// 设置事件监听器
function setupEventListeners() {
    // 单个模式事件
    document.getElementById('target-select').addEventListener('change', () => {
        if (currentMode === 'single') loadSingleChartData();
    });
    document.getElementById('time-range').addEventListener('change', () => {
        if (currentMode === 'single') loadSingleChartData();
    });
    document.getElementById('refresh-btn').addEventListener('click', () => {
        if (currentMode === 'single') loadSingleChartData();
    });

    // 多目标模式事件
    document.getElementById('multi-time-range').addEventListener('change', () => {
        if (currentMode === 'multi') loadMultiChartData();
    });
    document.getElementById('multi-refresh-btn').addEventListener('click', () => {
        if (currentMode === 'multi') loadMultiChartData();
    });
    document.getElementById('select-all-btn').addEventListener('click', selectAllTargets);
    document.getElementById('deselect-all-btn').addEventListener('click', deselectAllTargets);

    // 模式切换事件
    document.getElementById('single-mode-tab').addEventListener('click', () => {
        currentMode = 'single';
        loadSingleChartData();
    });
    document.getElementById('multi-mode-tab').addEventListener('click', () => {
        currentMode = 'multi';
        loadMultiChartData();
    });
}

// 加载目标列表
async function loadTargets() {
    try {
        const response = await fetch('/api/targets');
        targets = await response.json();
        
        // 填充单个模式的下拉框
        const select = document.getElementById('target-select');
        select.innerHTML = '<option value="">选择监控目标</option>';
        
        targets.forEach(target => {
            const option = document.createElement('option');
            option.value = target.id; // 使用target_id而不是addr
            // 隐藏地址显示为 ***
            const displayAddr = target.hide_addr ? '***' : target.addr;
            option.textContent = `${target.description} (${displayAddr})`;
            select.appendChild(option);
        });
        
        // 生成多目标模式的复选框
        generateTargetCheckboxes();
        
        // 默认选择第一个目标
        if (targets.length > 0) {
            select.value = targets[0].id;
            loadSingleChartData();
        }
    } catch (error) {
        console.error('加载目标失败:', error);
    }
}

// 生成目标复选框
function generateTargetCheckboxes() {
    const container = document.getElementById('targets-checkboxes');
    container.innerHTML = '';
    
    targets.forEach((target, index) => {
        const checkboxDiv = document.createElement('div');
        checkboxDiv.className = 'target-checkbox';
        
        const color = chartColors[index % chartColors.length];
        // 隐藏地址显示为 ***
        const displayAddr = target.hide_addr ? '***' : target.addr;
        
        checkboxDiv.innerHTML = `
            <label class="form-check-label">
                <input type="checkbox" class="form-check-input target-checkbox-input" 
                       value="${target.id}" data-index="${index}">
                <span>${target.description} (<span class="${target.hide_addr ? 'hidden-addr' : ''}">${displayAddr}</span>)</span>
                <div class="target-color-indicator" style="background-color: ${color}"></div>
            </label>
        `;
        
        container.appendChild(checkboxDiv);
        
        // 添加复选框变化事件
        const checkbox = checkboxDiv.querySelector('input[type="checkbox"]');
        checkbox.addEventListener('change', () => {
            if (currentMode === 'multi') loadMultiChartData();
        });
    });
}

// 全选目标
function selectAllTargets() {
    const checkboxes = document.querySelectorAll('.target-checkbox-input');
    checkboxes.forEach(checkbox => {
        checkbox.checked = true;
    });
    if (currentMode === 'multi') loadMultiChartData();
}

// 全不选目标
function deselectAllTargets() {
    const checkboxes = document.querySelectorAll('.target-checkbox-input');
    checkboxes.forEach(checkbox => {
        checkbox.checked = false;
    });
    if (currentMode === 'multi') loadMultiChartData();
}

// 获取选中的目标
function getSelectedTargets() {
    const checkboxes = document.querySelectorAll('.target-checkbox-input:checked');
    return Array.from(checkboxes).map(checkbox => ({
        id: checkbox.value, // 使用target_id
        index: parseInt(checkbox.dataset.index),
        target: targets.find(t => t.id === checkbox.value)
    }));
}

// 加载状态卡片
async function loadStatus() {
    try {
        const response = await fetch('/api/status');
        const statuses = await response.json();
        
        const container = document.getElementById('status-cards');
        container.innerHTML = '';
        
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
    col.className = 'col-md-4 col-lg-3 mb-3';
    
    const statusClass = status.success ? 'status-success' : 'status-failed';
    const statusText = status.success ? '正常' : '失败';
    const latencyText = status.success ? `${status.latency.toFixed(2)}ms` : 'N/A';
    const timeText = new Date(status.timestamp).toLocaleString('zh-CN');
    
    // 处理地址显示（隐藏地址显示为***加雾化效果）
    const addrDisplay = status.hide_addr ? 
        `<small class="text-muted hidden-addr">***</small><br>` : 
        (status.addr ? `<small class="text-muted">${status.addr}</small><br>` : '');
    
    col.innerHTML = `
        <div class="card status-card ${statusClass}">
            <div class="card-body">
                <h6 class="card-title">${status.description}</h6>
                <p class="card-text">
                    ${addrDisplay}
                    <span class="badge ${status.success ? 'bg-success' : 'bg-danger'}">${statusText}</span>
                    <span class="ms-2">${latencyText}</span><br>
                    <small class="text-muted">${timeText}</small>
                </p>
            </div>
        </div>
    `;
    
    return col;
}

// 初始化图表
function initChart() {
    const ctx = document.getElementById('ping-chart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: []
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: '延迟 (毫秒)'
                    }
                },
                x: {
                    title: {
                        display: true,
                        text: '时间'
                    }
                }
            },
            plugins: {
                title: {
                    display: true,
                    text: 'Ping 延迟趋势'
                },
                legend: {
                    display: true,
                    position: 'top'
                }
            },
            interaction: {
                intersect: false,
                mode: 'index'
            },
            elements: {
                point: {
                    radius: 2,
                    hoverRadius: 4
                }
            }
        }
    });
}

// 加载单个目标图表数据
async function loadSingleChartData() {
    const targetId = document.getElementById('target-select').value;
    const hours = document.getElementById('time-range').value;
    
    if (!targetId) {
        // 清空图表
        chart.data.labels = [];
        chart.data.datasets = [];
        chart.options.plugins.title.text = 'Ping 延迟趋势';
        chart.update();
        return;
    }
    
    try {
        const response = await fetch(`/api/ping-data?target_id=${encodeURIComponent(targetId)}&hours=${hours}`);
        const data = await response.json();
        
        // 找到目标描述
        const target = targets.find(t => t.id === targetId);
        const description = target ? target.description : targetId;
        const displayAddr = target && target.addr && !target.hide_addr ? target.addr : '';
        
        // 处理数据
        const labels = [];
        const latencies = [];
        
        data.forEach(item => {
            const time = new Date(item.timestamp);
            labels.push(time.toLocaleTimeString('zh-CN'));
            latencies.push(item.success ? item.latency : null);
        });
        
        // 更新图表
        chart.data.labels = labels;
        chart.data.datasets = [{
            label: `${description} - Ping 延迟 (ms)`,
            data: latencies,
            borderColor: singleModeColors.primary,
            backgroundColor: singleModeColors.gradient,
            borderWidth: 2,
            tension: 0.4,
            fill: true,
            spanGaps: true,
            pointBackgroundColor: singleModeColors.primary,
            pointBorderColor: '#fff',
            pointBorderWidth: 2,
            pointRadius: 3,
            pointHoverRadius: 5
        }];
        
        const titleAddr = displayAddr ? ` (${displayAddr})` : '';
        chart.options.plugins.title.text = `${description}${titleAddr} - Ping 延迟趋势`;
        chart.update();
        
    } catch (error) {
        console.error('加载图表数据失败:', error);
    }
}

// 加载多目标图表数据
async function loadMultiChartData() {
    const selectedTargets = getSelectedTargets();
    const hours = document.getElementById('multi-time-range').value;
    
    if (selectedTargets.length === 0) {
        // 清空图表
        chart.data.labels = [];
        chart.data.datasets = [];
        chart.options.plugins.title.text = 'Ping 延迟趋势 - 请选择监控目标';
        chart.update();
        return;
    }
    
    try {
        // 并行获取所有选中目标的数据
        const dataPromises = selectedTargets.map(async (selected) => {
            const response = await fetch(`/api/ping-data?target_id=${encodeURIComponent(selected.id)}&hours=${hours}`);
            const data = await response.json();
            return {
                ...selected,
                data: data
            };
        });
        
        const allData = await Promise.all(dataPromises);
        
        // 找到所有时间点的并集
        const allTimestamps = new Set();
        allData.forEach(targetData => {
            targetData.data.forEach(item => {
                allTimestamps.add(item.timestamp);
            });
        });
        
        // 排序时间点
        const sortedTimestamps = Array.from(allTimestamps).sort();
        const labels = sortedTimestamps.map(timestamp => 
            new Date(timestamp).toLocaleTimeString('zh-CN')
        );
        
        // 为每个目标创建数据集
        const datasets = allData.map(targetData => {
            const color = chartColors[targetData.index % chartColors.length];
            
            // 创建数据数组，对应所有时间点
            const dataPoints = sortedTimestamps.map(timestamp => {
                const dataPoint = targetData.data.find(item => item.timestamp === timestamp);
                return dataPoint && dataPoint.success ? dataPoint.latency : null;
            });
            
            // 隐藏地址显示为 ***
            const displayAddr = targetData.target.addr && !targetData.target.hide_addr ? 
                ` (${targetData.target.addr})` : (targetData.target.hide_addr ? ' (***)' : '');
            
            return {
                label: `${targetData.target.description}${displayAddr}`,
                data: dataPoints,
                borderColor: color,
                backgroundColor: color + '20',
                tension: 0.1,
                fill: false,
                spanGaps: true
            };
        });
        
        // 更新图表
        chart.data.labels = labels;
        chart.data.datasets = datasets;
        chart.options.plugins.title.text = `多目标 Ping 延迟趋势对比 (${selectedTargets.length}个目标)`;
        chart.update();
        
    } catch (error) {
        console.error('加载多目标图表数据失败:', error);
    }
}