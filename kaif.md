# TomatoBar 时间统计功能规划

## 需求概述

在 TomatoBar 应用中添加时间统计功能，用于展示用户的时间使用情况，主要包括：

1. **本周时间柱状图**：展示周一至周日每天的时间使用情况
2. **历史时间饼图**：展示所有时间块的历史累计时间占比
3. **数据本地存储**：数据精简化，避免占用过多内存

## 实现目标

### 1. 数据模型设计

- 设计每日时间使用记录的数据结构
- 设计历史时间统计的数据结构
- 确定数据存储和更新策略

### 2. 统计逻辑实现

- 实现时间累计的计算逻辑
- 实现按周、按类型的统计逻辑
- 实现数据重置功能

### 3. 用户界面开发

- 设计并实现柱状图视图
- 设计并实现饼图视图
- 将统计视图整合到现有应用界面

### 4. 数据持久化

- 实现数据的本地存储
- 确保数据的定期保存
- 优化数据存储，避免过度占用内存

## 实现步骤

### 1. 数据模型设计

#### 新增数据结构

```swift
// 日统计数据
struct DailyTimeStats: Codable, Identifiable {
    var id: String { date.formatted(date: .abbreviated, time: .omitted) }
    let date: Date
    var timeBlockUsage: [UUID: TimeInterval] // 每个时间块当天的使用时间
}

// 周统计数据
struct WeeklyTimeStats: Codable {
    var dailyStats: [DailyTimeStats] // 一周七天的数据
    var startDate: Date // 记录当前周的开始日期
}

// 历史统计数据
struct HistoricalTimeStats: Codable {
    var totalTimeBlockUsage: [UUID: TimeInterval] // 每个时间块的总使用时间
}
```

#### 在TimeBlockManager中添加统计属性

- 添加`currentWeekStats: WeeklyTimeStats`属性存储本周数据
- 添加`historicalStats: HistoricalTimeStats`属性存储历史数据

### 2. 统计逻辑实现

#### 时间累计逻辑

在计时器更新逻辑中添加时间统计：

```swift
// 伪代码示例
func updateTime() {
    if state == .active {
        remainingSeconds -= 1
        
        // 更新今日统计
        updateDailyStats(blockId: currentTimeBlock.id, seconds: 1)
        
        // 更新历史统计
        updateHistoricalStats(blockId: currentTimeBlock.id, seconds: 1)
    }
    
    // 原有代码继续执行...
}
```

#### 周数据管理

实现检测新一周开始的逻辑和手动重置功能：

```swift
// 检查并更新周数据
func checkAndUpdateWeek() {
    let calendar = Calendar.current
    let today = Date()
    
    // 检查是否需要开始新的一周
    if let weekStart = currentWeekStats.startDate {
        let components = calendar.dateComponents([.weekOfYear], from: weekStart, to: today)
        if components.weekOfYear ?? 0 > 0 {
            // 自动开始新的一周
            startNewWeek()
        }
    } else {
        // 首次运行，初始化周开始日期
        initializeWeekStart()
    }
}

// 手动重置周数据
func resetWeekStats() {
    startNewWeek()
}
```

#### 数据聚合方法

```swift
// 获取本周每日数据
func getDailyStatsForWeek() -> [DailyTimeStats] {
    return currentWeekStats.dailyStats
}

// 获取时间块总使用时间
func getTimeBlockTotalUsage() -> [UUID: TimeInterval] {
    return historicalStats.totalTimeBlockUsage
}
```

### 3. 用户界面开发

#### 创建统计视图

```swift
struct TimeStatsView: View {
    @ObservedObject var timeBlockManager: TimeBlockManager
    
    var body: some View {
        VStack {
            // 选项卡切换：周统计/历史统计
            TabView {
                WeeklyStatsView(weeklyStats: timeBlockManager.currentWeekStats)
                    .tabItem { Text("本周统计") }
                
                HistoricalStatsView(historicalStats: timeBlockManager.historicalStats)
                    .tabItem { Text("历史统计") }
            }
            
            // 底部按钮
            Button("重置本周数据") {
                timeBlockManager.resetWeekStats()
            }
        }
    }
}
```

#### 柱状图视图实现

使用SwiftUI创建柱状图，显示周一至周日的使用时间：

```swift
struct WeeklyStatsView: View {
    let weeklyStats: WeeklyTimeStats
    
    var body: some View {
        VStack {
            Text("本周时间使用情况")
                .font(.headline)
            
            HStack(alignment: .bottom, spacing: 12) {
                // 为每天创建柱状图
                ForEach(weeklyStats.dailyStats) { daily in
                    DayBarView(dayStats: daily)
                }
            }
            .padding()
        }
    }
}
```

#### 饼图视图实现

创建饼图展示历史使用时间分布：

```swift
struct HistoricalStatsView: View {
    let historicalStats: HistoricalTimeStats
    @ObservedObject var timeBlockManager: TimeBlockManager
    
    var body: some View {
        VStack {
            Text("历史时间分布")
                .font(.headline)
            
            PieChartView(data: prepareChartData())
                .frame(height: 200)
            
            // 显示总时间和分类明细
            VStack(alignment: .leading) {
                Text("总计时间: \(formatTotalTime())")
                
                ForEach(timeBlockManager.timeBlocks) { block in
                    if let time = historicalStats.totalTimeBlockUsage[block.id] {
                        HStack {
                            Circle()
                                .fill(colorForBlock(block))
                                .frame(width: 10, height: 10)
                            Text("\(block.name): \(formatTime(time))")
                        }
                    }
                }
            }
            .padding()
        }
    }
}
```

### 4. 数据持久化

#### 扩展现有存储机制

```swift
// 保存统计数据
func saveTimeStats() {
    do {
        let encoder = JSONEncoder()
        let weeklyData = try encoder.encode(currentWeekStats)
        let historicalData = try encoder.encode(historicalStats)
        
        // 保存到文件
        try weeklyData.write(to: weeklyStatsURL)
        try historicalData.write(to: historicalStatsURL)
    } catch {
        print("保存统计数据失败: \(error)")
    }
}

// 加载统计数据
func loadTimeStats() {
    // 加载周统计
    if let weeklyData = try? Data(contentsOf: weeklyStatsURL),
       let loadedWeekStats = try? JSONDecoder().decode(WeeklyTimeStats.self, from: weeklyData) {
        currentWeekStats = loadedWeekStats
    }
    
    // 加载历史统计
    if let historicalData = try? Data(contentsOf: historicalStatsURL),
       let loadedHistoricalStats = try? JSONDecoder().decode(HistoricalTimeStats.self, from: historicalData) {
        historicalStats = loadedHistoricalStats
    }
}
```

#### 数据优化策略

- 周统计数据仅保留最近一周
- 历史数据考虑按月合并，减少数据量
- 定期清理过旧的详细数据，只保留聚合结果

#### 自动保存机制

- 应用退出前保存统计数据
- 时间块完成或状态变化时保存数据
- 定期自动保存，防止数据丢失

## 实施阶段

1. **第一阶段 - 数据模型与基础逻辑**
   - 实现数据结构和存储机制
   - 实现基本的时间累计逻辑
   - 编写数据持久化代码

2. **第二阶段 - 用户界面开发**
   - 实现柱状图和饼图视图
   - 将统计视图整合到现有界面
   - 实现数据刷新和重置功能

3. **第三阶段 - 测试与优化**
   - 全面测试功能
   - 优化数据存储和处理性能
   - 完善异常处理和边缘情况

## 注意事项

1. **日期处理**
   - 需要处理时区、周起始日等日期相关问题
   - 处理跨天计时的情况

2. **数据准确性**
   - 确保应用崩溃时不丢失统计数据
   - 考虑用户调整系统时间的情况

3. **UI适配**
   - 确保图表在不同屏幕尺寸下的适配
   - 处理大量数据时的图表清晰度

4. **存储空间**
   - 监控数据文件大小，避免过度增长
   - 实现数据压缩或清理机制


