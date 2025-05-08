# TomatoBar 时间统计功能开发规划

## 需求概述

在 TomatoBar 应用中优化并添加时间统计功能，主要包括两部分：

1. **今日目标工作时间统计**：在时间块视图中显示今日工作目标总时间
2. **时间统计栏目**：添加新的时间统计标签页，包含今日统计和历史统计

## 功能详细说明

### 1. 今日目标工作时间

- 在时间块视图顶部显示今日工作目标总时间
- 该时间根据所有"工作"标签时间块的时长自动汇总计算
- 休息类型的时间块不计入工作目标总时间
- 工作目标时间不随时间块倒计时而变化，仅反映计划时间
- 用户不能直接编辑或删除此总时间，它完全由时间块配置决定

### 2. 时间统计栏目

#### 2.1 今日时间统计

- 使用条状图显示今日已完成的工作时间和休息时间
- 工作时间统计条最长显示14小时
- 休息时间统计条最长显示10小时
- 根据用户实际使用的时间块计时来累计时间，按进度条方式直观展示
- 当用户点击"刷新时间"按钮时，今日统计数据会重置为零

#### 2.2 历史时间统计

- 使用饼图展示自软件安装以来所有时间块使用占比
- 数据持久化存储在本地，轻量化处理避免占用过多内存
- 历史数据会持续累积更新，不会因任何操作被重置

## 开发计划

### 第一阶段 - 数据模型与基础逻辑（5天）

1. **创建基础数据结构（1天）**
   ```swift
   // 今日工作目标时间计算
   extension TimeBlockManager {
       // 计算今日工作目标总时间（分钟）
       var todayWorkTargetMinutes: Int {
           return timeBlocks
               .filter { $0.type == .work }
               .reduce(0) { $0 + $1.duration }
       }
       
       // 格式化显示（小时:分钟）
       var formattedTodayWorkTarget: String {
           let hours = todayWorkTargetMinutes / 60
           let minutes = todayWorkTargetMinutes % 60
           return String(format: "%d:%02d", hours, minutes)
       }
   }
   
   // 今日统计数据结构
   struct DailyTimeStats: Codable {
       var date: Date
       var workTimeSeconds: Int = 0      // 工作时间累计（秒）
       var breakTimeSeconds: Int = 0     // 休息时间累计（秒）
       
       // 检查是否是今天的数据
       func isToday() -> Bool {
           return Calendar.current.isDateInToday(date)
       }
       
       // 重置今日数据
       mutating func reset() {
           workTimeSeconds = 0
           breakTimeSeconds = 0
           date = Date()
       }
   }
   
   // 历史统计数据结构
   struct HistoricalTimeStats: Codable {
       // 每个时间块ID对应的总使用时间（秒）
       var timeBlockUsage: [UUID: Int] = [:]
       
       // 更新时间块使用时间
       mutating func updateUsage(blockId: UUID, seconds: Int) {
           let currentValue = timeBlockUsage[blockId] ?? 0
           timeBlockUsage[blockId] = currentValue + seconds
       }
       
       // 获取总计时间（秒）
       var totalSeconds: Int {
           return timeBlockUsage.values.reduce(0, +)
       }
       
       // 计算每个时间块的使用占比
       func calculatePercentages() -> [UUID: Double] {
           let total = Double(totalSeconds)
           guard total > 0 else { return [:] }
           
           var percentages: [UUID: Double] = [:]
           for (id, seconds) in timeBlockUsage {
               percentages[id] = Double(seconds) / total
           }
           return percentages
       }
   }

   // 在TimeBlockManager中添加相关属性
   class TimeBlockManager: ObservableObject {
       // 现有属性...
       
       // 今日统计数据
       @Published var dailyStats: DailyTimeStats = DailyTimeStats(date: Date())
       
       // 历史统计数据
       @Published var historicalStats: HistoricalTimeStats = HistoricalTimeStats()
       
       // 文件URL
       private var dailyStatsFileURL: URL? {
           // 返回今日统计数据文件URL
       }
       
       private var historicalStatsFileURL: URL? {
           // 返回历史统计数据文件URL
       }
   }
   ```

2. **实现基础统计逻辑（2天）**
   ```swift
   // 在现有的updateTime方法中添加统计逻辑
   func updateTime() {
       if currentState == .active {
           // 现有的逻辑...
           remainingSeconds -= 1
           
           // 添加统计逻辑
           if let currentBlock = currentTimeBlock {
               // 检查并确保dailyStats是今天的数据
               if !dailyStats.isToday() {
                   dailyStats.reset()
               }
               
               // 更新今日统计
               if currentBlock.type == .work {
                   dailyStats.workTimeSeconds += 1
               } else {
                   dailyStats.breakTimeSeconds += 1
               }
               
               // 更新历史统计
               historicalStats.updateUsage(blockId: currentBlock.id, seconds: 1)
               
               // 自动保存数据（考虑节流以避免频繁IO）
               if remainingSeconds % 60 == 0 { // 每分钟保存一次
                   saveTimeStats()
               }
           }
       }
       
       // 其余逻辑...
   }
   
   // 在刷新时间的方法中添加统计重置
   func refreshAllTimeBlocks() {
       // 现有逻辑...
       
       // 重置今日统计
       dailyStats.reset()
       
       // 保存更新后的统计数据
       saveTimeStats()
   }
   ```

3. **实现数据持久化（2天）**
   ```swift
   // 保存统计数据
   func saveTimeStats() {
       do {
           let encoder = JSONEncoder()
           
           // 保存今日统计
           if let url = dailyStatsFileURL {
               let dailyData = try encoder.encode(dailyStats)
               try dailyData.write(to: url)
           }
           
           // 保存历史统计
           if let url = historicalStatsFileURL {
               let historicalData = try encoder.encode(historicalStats)
               try historicalData.write(to: url)
           }
       } catch {
           print("保存统计数据失败: \(error)")
       }
   }
   
   // 加载统计数据
   func loadTimeStats() {
       let decoder = JSONDecoder()
       
       // 加载今日统计
       if let url = dailyStatsFileURL,
          let data = try? Data(contentsOf: url),
          let loadedStats = try? decoder.decode(DailyTimeStats.self, from: data) {
           dailyStats = loadedStats
           // 如果不是今天的数据，重置
           if !dailyStats.isToday() {
               dailyStats.reset()
           }
       }
       
       // 加载历史统计
       if let url = historicalStatsFileURL,
          let data = try? Data(contentsOf: url),
          let loadedStats = try? decoder.decode(HistoricalTimeStats.self, from: data) {
           historicalStats = loadedStats
       }
   }
   ```

### 第二阶段 - 用户界面开发（7天）

1. **设计并实现基础UI组件（4天）**
   ```swift
   // 今日目标工作时间组件
   struct TodayWorkTargetView: View {
       @ObservedObject var timeBlockManager: TimeBlockManager
       
       var body: some View {
           HStack {
               Image(systemName: "target")
                   .foregroundColor(.blue)
               
               Text("今日工作目标")
                   .font(.subheadline)
                   .foregroundColor(.secondary)
               
               Spacer()
               
               Text(timeBlockManager.formattedTodayWorkTarget)
                   .font(.headline)
                   .foregroundColor(.blue)
           }
           .padding(.horizontal)
           .padding(.vertical, 8)
           .background(Color.blue.opacity(0.1))
           .cornerRadius(8)
           .padding(.horizontal)
           .padding(.top, 8)
       }
   }
   
   // 进度条组件（条形图）
   struct TimeBarView: View {
       let title: String
       let currentSeconds: Int
       let maxHours: Int
       let color: Color
       
       private var maxSeconds: Int {
           return maxHours * 3600
       }
       
       private var progress: Double {
           let progress = Double(currentSeconds) / Double(maxSeconds)
           return min(progress, 1.0) // 确保不超过1.0
       }
       
       private var formattedTime: String {
           let hours = currentSeconds / 3600
           let minutes = (currentSeconds % 3600) / 60
           
           if hours > 0 {
               return "\(hours):\(String(format: "%02d", minutes))"
           } else {
               return "\(minutes)分钟"
           }
       }
       
       var body: some View {
           VStack(alignment: .leading, spacing: 4) {
               HStack {
                   Text(title)
                       .font(.subheadline)
                       .foregroundColor(.secondary)
                   
                   Spacer()
                   
                   Text(formattedTime)
                       .font(.subheadline)
                       .foregroundColor(color)
               }
               
               // 进度条
               GeometryReader { geo in
                   ZStack(alignment: .leading) {
                       // 背景
                       RoundedRectangle(cornerRadius: 4)
                           .fill(Color.secondary.opacity(0.2))
                           .frame(height: 8)
                       
                       // 进度
                       RoundedRectangle(cornerRadius: 4)
                           .fill(color)
                           .frame(width: geo.size.width * progress, height: 8)
                   }
               }
               .frame(height: 8)
               
               // 最大时间标注
               HStack {
                   Spacer()
                   Text("最大\(maxHours)小时")
                       .font(.caption2)
                       .foregroundColor(.secondary)
               }
           }
       }
   }
   
   // 饼图数据模型
   struct PieSliceData: Identifiable {
       var id: UUID
       var value: Double
       var color: Color
   }
   
   // 饼图组件
   struct PieChartView: View {
       let data: [PieSliceData]
       let timeBlocks: [TimeBlock]
       
       var body: some View {
           GeometryReader { geo in
               ZStack {
                   ForEach(0..<data.count, id: \.self) { i in
                       PieSlice(
                           startAngle: startAngle(index: i),
                           endAngle: endAngle(index: i),
                           color: data[i].color
                       )
                   }
                   
                   // 中心孔
                   Circle()
                       .fill(Color(.systemBackground))
                       .frame(width: geo.size.width * 0.5, height: geo.size.height * 0.5)
                   
                   // 中心文字
                   Text("\(Int(totalPercent * 100))%")
                       .font(.title)
                       .bold()
               }
           }
           .aspectRatio(1, contentMode: .fit)
       }
       
       private var totalPercent: Double {
           data.reduce(0) { $0 + $1.value }
       }
       
       private func startAngle(index: Int) -> Angle {
           if index == 0 { return .degrees(0) }
           
           let sum = data[0..<index].reduce(0) { $0 + $1.value }
           return .degrees(sum * 360)
       }
       
       private func endAngle(index: Int) -> Angle {
           let sum = data[0...index].reduce(0) { $0 + $1.value }
           return .degrees(sum * 360)
       }
   }
   
   struct PieSlice: View {
       var startAngle: Angle
       var endAngle: Angle
       var color: Color
       
       var body: some View {
           Path { path in
               path.move(to: CGPoint(x: 0.5, y: 0.5))
               path.addArc(
                   center: CGPoint(x: 0.5, y: 0.5),
                   radius: 0.5,
                   startAngle: startAngle,
                   endAngle: endAngle,
                   clockwise: false
               )
               path.closeSubpath()
           }
           .fill(color)
           .aspectRatio(1, contentMode: .fit)
       }
   }
   ```

2. **实现统计视图（2天）**
   ```swift
   struct TimeStatsView: View {
       @ObservedObject var timeBlockManager: TimeBlockManager
       
       var body: some View {
           ScrollView {
               VStack(spacing: 20) {
                   // 今日统计区域
                   todayStatsSection
                   
                   Divider()
                   
                   // 历史统计区域
                   historicalStatsSection
               }
               .padding()
           }
       }
       
       // 今日统计部分
       private var todayStatsSection: some View {
           VStack(alignment: .leading, spacing: 12) {
               Text("今日时间统计")
                   .font(.headline)
               
               // 工作时间条形图
               TimeBarView(
                   title: "工作时间",
                   currentSeconds: timeBlockManager.dailyStats.workTimeSeconds,
                   maxHours: 14,
                   color: .blue
               )
               
               // 休息时间条形图
               TimeBarView(
                   title: "休息时间",
                   currentSeconds: timeBlockManager.dailyStats.breakTimeSeconds,
                   maxHours: 10,
                   color: .green
               )
               
               // 显示具体数值
               HStack {
                   Spacer()
                   VStack(alignment: .trailing) {
                       Text("工作: \(formatTime(timeBlockManager.dailyStats.workTimeSeconds))")
                       Text("休息: \(formatTime(timeBlockManager.dailyStats.breakTimeSeconds))")
                   }
                   .font(.caption)
                   .foregroundColor(.secondary)
               }
           }
       }
       
       // 历史统计部分
       private var historicalStatsSection: some View {
           VStack(alignment: .leading, spacing: 12) {
               Text("历史时间统计")
                   .font(.headline)
               
               // 饼图
               if timeBlockManager.historicalStats.totalSeconds > 0 {
                   PieChartView(
                       data: prepareChartData(),
                       timeBlocks: timeBlockManager.timeBlocks
                   )
                   .frame(height: 200)
                   
                   // 图例
                   ForEach(timeBlockManager.timeBlocks) { block in
                       if let seconds = timeBlockManager.historicalStats.timeBlockUsage[block.id], seconds > 0 {
                           HStack {
                               Circle()
                                   .fill(block.color.toColor())
                                   .frame(width: 10, height: 10)
                               
                               Text(block.name)
                               
                               Spacer()
                               
                               Text(formatTime(seconds))
                                   .foregroundColor(.secondary)
                           }
                           .font(.caption)
                       }
                   }
               } else {
                   Text("暂无历史数据")
                       .foregroundColor(.secondary)
                       .frame(maxWidth: .infinity, alignment: .center)
                       .padding()
               }
           }
       }
       
       // 准备饼图数据
       private func prepareChartData() -> [PieSliceData] {
           let percentages = timeBlockManager.historicalStats.calculatePercentages()
           
           return timeBlockManager.timeBlocks.compactMap { block in
               guard let percent = percentages[block.id], percent > 0 else { return nil }
               return PieSliceData(
                   id: block.id,
                   value: percent,
                   color: block.color.toColor()
               )
           }
       }
       
       // 格式化时间
       private func formatTime(_ seconds: Int) -> String {
           let hours = seconds / 3600
           let minutes = (seconds % 3600) / 60
           
           if hours > 0 {
               return "\(hours)小时\(minutes)分钟"
           } else {
               return "\(minutes)分钟"
           }
       }
   }
   ```

3. **整合到现有应用（1天）**
   ```swift
   // 更新主视图添加时间统计标签
   struct TBPopoverView: View {
       @State private var selectedTab: Int = 0
       @ObservedObject var timer = TBTimer()
       
       var body: some View {
           VStack {
               // 顶部选项卡
               Picker("", selection: $selectedTab) {
                   Text("时间块").tag(0)
                   Text("时间统计").tag(1)
                   Text("设置").tag(2)
               }
               .pickerStyle(SegmentedPickerStyle())
               .padding(.horizontal)
               .padding(.top, 8)
               
               // 内容视图
               Group {
                   if selectedTab == 0 {
                       TimeBlocksView(timer: timer)
                   } else if selectedTab == 1 {
                       TimeStatsView(timeBlockManager: timer.timeBlockManager)
                   } else {
                       SettingsView()
                   }
               }
           }
           .frame(width: 240)
       }
   }
   
   // 更新时间块视图添加工作目标时间
   struct TimeBlocksView: View {
       @ObservedObject var timer: TBTimer
       
       var body: some View {
           VStack(spacing: 0) {
               // 添加工作目标时间展示
               TodayWorkTargetView(timeBlockManager: timer.timeBlockManager)
               
               // 现有的控制按钮行
               HStack {
                   // 刷新按钮
                   Button {
                       timer.refreshAllTimeBlocks()
                   } label: {
                       Image(systemName: "arrow.counterclockwise")
                           .foregroundColor(.secondary)
                   }
                   .buttonStyle(.plain)
                   .help("刷新所有时间")
                   
                   // 其他控制按钮...
               }
               .padding(.horizontal)
               .padding(.vertical, 8)
               
               // 时间块列表
               // 现有代码...
           }
       }
   }
   ```

### 第三阶段 - 测试与优化（3天）

1. **全面功能测试（1天）**
   - 测试今日工作目标时间计算
   - 测试今日统计数据累计和重置
   - 测试历史统计数据累计和持久化

2. **性能优化（1天）**
   - 优化数据处理逻辑，减少计算开销
   - 优化数据存储策略，减少磁盘IO
   - 优化图表渲染，提高展示效率

3. **修复问题与收尾（1天）**
   - 修复发现的任何问题
   - 优化异常处理和边缘情况
   - 最终代码审查和整理

## 注意事项

1. **数据准确性**
   - 处理应用重启后的数据恢复
   - 确保计时暂停和恢复不会影响统计
   - 考虑系统休眠/唤醒对计时的影响

2. **性能优化**
   - 避免频繁的文件IO操作
   - 使用节流机制减少不必要的更新
   - 历史数据可考虑周期性聚合以减少存储量

3. **用户体验**
   - 确保统计视图加载速度快
   - 提供清晰的数据可视化效果
   - 保持界面简洁，不过度占用空间

4. **日期处理**
   - 正确处理跨天使用的情况
   - 考虑时区变化对"今天"判断的影响
   - 确保日期比较逻辑准确


