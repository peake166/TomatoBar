import SwiftState
import Foundation
import SwiftUI
import Combine

// 时间块数据模型
struct TimeBlock: Identifiable, Codable {
    var id = UUID()
    var name: String
    var duration: Int  // 以分钟为单位
    var type: TimeBlockType
    var color: TimeBlockColor
    var isActive: Bool = false
    var savedRemainingSeconds: Int? = nil // 保存的剩余时间（秒）
    
    // 添加自定义提醒选项
    var reminders: [TimeBlockReminder] = []
    
    // 创建默认时间块
    static func createDefault(type: TimeBlockType) -> TimeBlock {
        switch type {
        case .work:
            return TimeBlock(name: "工作", duration: 0, type: .work, color: .red)
        case .shortBreak:
            return TimeBlock(name: "短休息", duration: 5, type: .shortBreak, color: .green)
        case .longBreak:
            return TimeBlock(name: "长休息", duration: 15, type: .longBreak, color: .blue)
        }
    }
}

// 时间块类型
enum TimeBlockType: String, Codable {
    case work
    case shortBreak
    case longBreak
}

// 时间块颜色
enum TimeBlockColor: String, Codable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray
}

// 时间块状态类型
enum TimeBlockState: StateType {
    case idle       // 空闲状态
    case active     // 活动状态
    case paused     // 暂停状态
    case finished   // 完成状态
}

// 时间块状态事件
enum TimeBlockEvent: EventType {
    case start      // 开始
    case pause      // 暂停
    case resume     // 继续
    case skip       // 跳过
    case finish     // 完成
    case reset      // 重置
}

// 状态机类型定义
typealias TimeBlockStateMachine = StateMachine<TimeBlockState, TimeBlockEvent>

// 时间块提醒数据模型
struct TimeBlockReminder: Identifiable, Codable {
    var id = UUID()
    var triggerTime: Int // 触发时间（秒），相对于时间块开始的时间
    var message: String  // 提醒消息
    var soundEnabled: Bool = true // 是否启用声音
    var enabled: Bool = true // 是否启用这个提醒
    
    // 判断是否应该在指定的剩余时间触发提醒
    func shouldTrigger(at remainingSeconds: Int, totalDuration: Int) -> Bool {
        if !enabled { return false }
        let elapsedSeconds = totalDuration * 60 - remainingSeconds
        return elapsedSeconds == triggerTime
    }
}

// 时间块管理器
class TimeBlockManager: ObservableObject {
    // 时间块集合
    @Published var timeBlocks: [TimeBlock] = []
    // 当前活动的时间块索引
    @Published var currentBlockIndex: Int? = nil
    // 剩余时间（秒）
    @Published var remainingSeconds: Int = 0
    // 状态机
    private var stateMachine = TimeBlockStateMachine(state: .idle)
    // 完成的时间块数量
    @Published var completedWorkBlocks: Int = 0
    // 下一个休息是否为长休息
    @Published var isNextBreakLong: Bool = false
    
    // 默认休息设置
    @Published var workIntervalsInSet: Int = 4
    
    // 用于跟踪已触发的提醒
    private var triggeredReminders: Set<UUID> = []
    
    // 今日统计数据
    @Published var dailyStats: DailyTimeStats = DailyTimeStats(date: Date())
    
    // 历史统计数据
    @Published var historicalStats: HistoricalTimeStats = HistoricalTimeStats()
    
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
    
    // 持久化存储的文件URL
    private var timeBlocksFileURL: URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentDirectory.appendingPathComponent("timeBlocks.json")
    }
    
    // 存储状态的文件URL
    private var stateFileURL: URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentDirectory.appendingPathComponent("timeBlockState.json")
    }
    
    // 用于存储订阅的集合
    private var cancellables = Set<AnyCancellable>()
    
    // 统计数据文件URL
    private var dailyStatsFileURL: URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentDirectory.appendingPathComponent("dailyStats.json")
    }
    
    private var historicalStatsFileURL: URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentDirectory.appendingPathComponent("historicalStats.json")
    }
    
    // 获取指定时间块的剩余秒数
    func getRemainingSeconds(for timeBlockId: UUID) -> Int? {
        // 如果不是当前活动的时间块，返回保存的剩余时间（如果有）
        if let index = timeBlocks.firstIndex(where: { $0.id == timeBlockId }) {
            if currentBlockIndex == index {
                // 如果是当前活动的时间块，返回实时的剩余秒数
                return remainingSeconds
            } else {
                // 返回保存的剩余秒数（如果有）
                return timeBlocks[index].savedRemainingSeconds
            }
        }
        return nil
    }
    
    init() {
        // 尝试加载保存的时间块数据
        if !loadTimeBlocks() {
            // 如果加载失败，创建默认的时间块
            createDefaultTimeBlocks()
        }
        
        // 尝试加载保存的状态
        if !loadState() {
            // 如果加载失败，使用默认的空闲状态
            stateMachine = TimeBlockStateMachine(state: .idle)
        }
        
        // 加载统计数据
        loadTimeStats()
        
        // 设置状态机路由
        setupStateMachine()
        
        // 添加自动保存功能
        setupAutosave()
    }
    
    // 设置自动保存
    private func setupAutosave() {
        // 使用组合发布者来监听所有可能的状态变化
        Publishers.CombineLatest3($timeBlocks, $currentBlockIndex, $remainingSeconds)
            .debounce(for: .seconds(1.0), scheduler: RunLoop.main) // 防止过于频繁的保存
            .sink { [weak self] _, _, _ in
                self?.saveTimeBlocks()
                self?.saveState()
            }
            .store(in: &cancellables)
            
        // 添加统计数据的自动保存
        Publishers.CombineLatest($dailyStats, $historicalStats)
            .debounce(for: .seconds(5.0), scheduler: RunLoop.main) // 使用更长的延迟，减少IO操作
            .sink { [weak self] _, _ in
                self?.saveTimeStats()
            }
            .store(in: &cancellables)
    }
    
    // 创建默认时间块集合
    private func createDefaultTimeBlocks() {
        timeBlocks = [
            TimeBlock.createDefault(type: .work),
            TimeBlock.createDefault(type: .shortBreak),
            TimeBlock.createDefault(type: .longBreak)
        ]
    }
    
    // 设置状态机
    private func setupStateMachine() {
        // 从空闲到活动状态
        stateMachine.addRoutes(event: .start, transitions: [.idle => .active])
        // 活动状态可以暂停
        stateMachine.addRoutes(event: .pause, transitions: [.active => .paused])
        // 从暂停恢复到活动状态
        stateMachine.addRoutes(event: .resume, transitions: [.paused => .active])
        // 活动状态可以完成或跳过
        stateMachine.addRoutes(event: .finish, transitions: [.active => .finished])
        stateMachine.addRoutes(event: .skip, transitions: [.active => .finished])
        // 从任何状态回到空闲
        stateMachine.addRoutes(event: .reset, transitions: [.any => .idle])
        
        // 从完成状态回到空闲状态（自动转换）
        stateMachine.addRoutes(event: .start, transitions: [.finished => .active])
    }
    
    // 获取当前时间块
    var currentTimeBlock: TimeBlock? {
        guard let index = currentBlockIndex, index >= 0, index < timeBlocks.count else {
            return nil
        }
        return timeBlocks[index]
    }
    
    // 获取当前状态
    var currentState: TimeBlockState {
        return stateMachine.state
    }
    
    // 开始时间块
    func startTimeBlock(index: Int) {
        guard index >= 0, index < timeBlocks.count else { return }
        
        // 设置当前索引并更新状态
        currentBlockIndex = index
        var block = timeBlocks[index]
        block.isActive = true
        timeBlocks[index] = block
        
        // 如果有保存的剩余时间，使用它，否则使用全新的时间
        if let savedSeconds = block.savedRemainingSeconds {
            remainingSeconds = savedSeconds
        } else {
            remainingSeconds = block.duration * 60
        }
        
        // 重置已触发的提醒
        triggeredReminders.removeAll()
        
        // 触发状态转换
        stateMachine <-! .start
    }
    
    // 暂停当前时间块
    func pauseCurrentTimeBlock() {
        guard currentBlockIndex != nil && stateMachine.state == .active else { return }
        
        // 保存当前剩余时间到时间块中
        if let index = currentBlockIndex {
            var block = timeBlocks[index]
            block.savedRemainingSeconds = remainingSeconds
            timeBlocks[index] = block
        }
        
        stateMachine <-! .pause
    }
    
    // 恢复当前时间块
    func resumeCurrentTimeBlock() {
        guard currentBlockIndex != nil && stateMachine.state == .paused else { return }
        stateMachine <-! .resume
    }
    
    // 完成当前时间块
    func finishCurrentTimeBlock() {
        guard let index = currentBlockIndex else { return }
        
        // 更新时间块状态
        var block = timeBlocks[index]
        
        // 保存剩余时间数据
        block.savedRemainingSeconds = remainingSeconds
        
        block.isActive = false
        timeBlocks[index] = block
        
        // 保存更改
        saveTimeBlocks()
        
        // 处理完成后的逻辑
        if block.type == .work {
            completedWorkBlocks += 1
            // 检查是否需要长休息
            isNextBreakLong = completedWorkBlocks >= workIntervalsInSet
            if isNextBreakLong {
                completedWorkBlocks = 0
            }
        }
        
        // 触发状态转换
        stateMachine <-! .finish
        
        // 清空当前索引
        currentBlockIndex = nil
    }
    
    // 跳过当前时间块
    func skipCurrentTimeBlock() {
        guard let index = currentBlockIndex else { return }
        
        // 保存当前剩余时间
        var block = timeBlocks[index]
        block.savedRemainingSeconds = remainingSeconds
        block.isActive = false
        timeBlocks[index] = block
        
        // 保存更改
        saveTimeBlocks()
        
        // 触发状态转换
        stateMachine <-! .skip
        
        // 清空当前索引
        currentBlockIndex = nil
    }
    
    // 重置所有状态
    func reset() {
        // 重置当前索引，但保留剩余时间数据
        if let index = currentBlockIndex {
            var block = timeBlocks[index]
            
            // 保存剩余时间，确保它不会丢失
            if block.savedRemainingSeconds == nil || block.savedRemainingSeconds != remainingSeconds {
                // 只有当剩余时间与已保存的不同时才更新
                block.savedRemainingSeconds = remainingSeconds
            }
            
            // 设置为非活动状态
            block.isActive = false
            
            // 更新时间块
            timeBlocks[index] = block
            
            // 保存更改
            saveTimeBlocks()
        }
        
        currentBlockIndex = nil
        remainingSeconds = 0
        
        // 触发状态转换
        stateMachine <-! .reset
    }
    
    // 更新时间（每秒调用一次）
    func updateTime() {
        guard currentBlockIndex != nil && stateMachine.state == .active else { return }
        
        if remainingSeconds > 0 {
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
            
            // 检查是否需要触发提醒
            checkReminders()
        }
        
        // 如果时间到了，暂停而不是自动完成
        if remainingSeconds <= 0 {
            // 保存当前状态
            if let index = currentBlockIndex {
                var block = timeBlocks[index]
                block.savedRemainingSeconds = 0
                timeBlocks[index] = block
            }
            
            // 创建完成通知
            // 但不自动结束，只是暂停，让用户决定下一步操作
            NotificationCenter.default.post(
                name: Notification.Name("TimeBlockTimeUpEvent"),
                object: nil,
                userInfo: ["timeBlockIndex": currentBlockIndex as Any]
            )
            
            // 触发暂停状态转换
            stateMachine <-! .pause
        }
    }
    
    // 检查并触发提醒
    private func checkReminders() {
        guard let currentIndex = currentBlockIndex else { return }
        
        let currentBlock = timeBlocks[currentIndex]
        let totalDuration = currentBlock.duration
        
        // 检查每个提醒是否应该触发
        for reminder in currentBlock.reminders {
            // 如果这个提醒ID已经在已触发集合中，跳过
            if triggeredReminders.contains(reminder.id) {
                continue
            }
            
            // 检查是否应该触发提醒
            if reminder.shouldTrigger(at: remainingSeconds, totalDuration: totalDuration) {
                // 添加到已触发集合
                triggeredReminders.insert(reminder.id)
                
                // 触发提醒（可以通过通知中心发送）
                triggerReminder(reminder: reminder, timeBlock: currentBlock)
            }
        }
    }
    
    // 触发提醒
    private func triggerReminder(reminder: TimeBlockReminder, timeBlock: TimeBlock) {
        // 这里我们需要通过某种方式将提醒发送出去
        // 在真实实现中，这可能会调用NotificationCenter的方法
        NotificationCenter.default.post(
            name: Notification.Name("TimeBlockReminderTriggered"),
            object: nil,
            userInfo: [
                "reminder": reminder,
                "timeBlock": timeBlock
            ]
        )
    }
    
    // 添加新的时间块
    func addTimeBlock(name: String, duration: Int, type: TimeBlockType, color: TimeBlockColor) {
        let newBlock = TimeBlock(name: name, duration: duration, type: type, color: color)
        timeBlocks.append(newBlock)
    }
    
    // 更新时间块
    func updateTimeBlock(id: UUID, name: String? = nil, duration: Int? = nil, type: TimeBlockType? = nil, color: TimeBlockColor? = nil) {
        guard let index = timeBlocks.firstIndex(where: { $0.id == id }) else { return }
        
        var block = timeBlocks[index]
        
        if let name = name {
            block.name = name
        }
        
        if let duration = duration {
            // 保存旧的持续时间，用于计算比例
            let oldDuration = block.duration
            
            // 更新持续时间
            block.duration = duration
            
            // 如果当前是活动的时间块，更新剩余时间
            if currentBlockIndex == index && stateMachine.state == .active {
                // 更新剩余时间（重新设置为新duration对应的秒数）
                remainingSeconds = duration * 60
            }
            
            // 处理保存的剩余时间
            if let savedSeconds = block.savedRemainingSeconds {
                // 如果剩余时间等于旧持续时间（即未开始计时），则直接使用新持续时间
                if savedSeconds == oldDuration * 60 {
                    block.savedRemainingSeconds = duration * 60
                }
                // 如果已经开始计时并且有剩余时间，按比例调整剩余时间
                else if oldDuration > 0 {
                    // 计算已使用的比例
                    let usedRatio = 1.0 - (Double(savedSeconds) / Double(oldDuration * 60))
                    // 按照相同比例应用到新的持续时间
                    let newRemainingSeconds = Int(Double(duration * 60) * (1.0 - usedRatio))
                    block.savedRemainingSeconds = max(0, newRemainingSeconds)
                } else {
                    // 如果旧持续时间为0，直接使用新持续时间
                    block.savedRemainingSeconds = duration * 60
                }
            } else {
                // 如果没有已保存的剩余时间，设置为新的持续时间
                block.savedRemainingSeconds = duration * 60
            }
        }
        
        if let type = type {
            block.type = type
        }
        
        if let color = color {
            block.color = color
        }
        
        // 打印调试信息
        print("更新时间块: \(block.name), ID: \(block.id), 持续时间: \(block.duration)分钟, 剩余秒数: \(block.savedRemainingSeconds ?? 0)")
        
        timeBlocks[index] = block
        
        // 保存更改
        saveTimeBlocks()
    }
    
    // 删除时间块
    func deleteTimeBlock(id: UUID) {
        timeBlocks.removeAll { $0.id == id }
    }
    
    // 保存时间块数据
    func saveTimeBlocks() {
        guard let fileURL = timeBlocksFileURL else { return }
        
        // 确保当前时间块的剩余时间被保存
        if let currentIndex = currentBlockIndex {
            var block = timeBlocks[currentIndex]
            block.savedRemainingSeconds = remainingSeconds
            timeBlocks[currentIndex] = block
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(timeBlocks)
            try data.write(to: fileURL)
            print("时间块数据已保存")
        } catch {
            print("保存时间块数据失败: \(error)")
        }
    }
    
    // 加载时间块数据
    func loadTimeBlocks() -> Bool {
        guard let fileURL = timeBlocksFileURL else { return false }
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                timeBlocks = try decoder.decode([TimeBlock].self, from: data)
                print("时间块数据已加载")
                return true
            }
        } catch {
            print("加载时间块数据失败: \(error)")
        }
        
        return false
    }
    
    // 保存当前状态数据
    func saveState() {
        guard let fileURL = stateFileURL else { return }
        
        // 在保存状态前，确保当前剩余时间被保存到当前时间块中
        if let index = currentBlockIndex {
            var block = timeBlocks[index]
            block.savedRemainingSeconds = remainingSeconds
            timeBlocks[index] = block
        }
        
        // 创建状态数据结构
        let stateData = TimeBlockStateData(
            currentState: stateMachine.state,
            currentBlockIndex: currentBlockIndex,
            remainingSeconds: remainingSeconds,
            completedWorkBlocks: completedWorkBlocks,
            isNextBreakLong: isNextBreakLong
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(stateData)
            try data.write(to: fileURL)
            print("状态数据已保存")
        } catch {
            print("保存状态数据失败: \(error)")
        }
    }
    
    // 加载状态数据
    func loadState() -> Bool {
        guard let fileURL = stateFileURL else { return false }
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                let stateData = try decoder.decode(TimeBlockStateData.self, from: data)
                
                // 只恢复部分状态：完成的工作数和是否需要长休息
                // 不恢复活动状态，总是以空闲状态启动
                stateMachine = TimeBlockStateMachine(state: .idle)
                currentBlockIndex = nil
                
                // 不需要恢复 remainingSeconds 到活动状态，因为我们已经把它保存在每个时间块中了
                remainingSeconds = 0
                
                // 恢复其他统计数据
                completedWorkBlocks = stateData.completedWorkBlocks
                isNextBreakLong = stateData.isNextBreakLong
                
                print("部分状态数据已加载（应用启动时总是空闲状态）")
                return true
            }
        } catch {
            print("加载状态数据失败: \(error)")
        }
        
        return false
    }
    
    // 移动时间块（改变顺序）
    func moveTimeBlock(from source: IndexSet, to destination: Int) {
        timeBlocks.move(fromOffsets: source, toOffset: destination)
        saveTimeBlocks()
    }
    
    // 添加提醒到时间块
    func addReminderToTimeBlock(timeBlockId: UUID, triggerTime: Int, message: String, soundEnabled: Bool = true) {
        guard let index = timeBlocks.firstIndex(where: { $0.id == timeBlockId }) else { return }
        
        let reminder = TimeBlockReminder(
            triggerTime: triggerTime,
            message: message,
            soundEnabled: soundEnabled
        )
        
        var block = timeBlocks[index]
        block.reminders.append(reminder)
        timeBlocks[index] = block
        
        // 保存更改
        saveTimeBlocks()
    }
    
    // 更新时间块的提醒
    func updateReminder(timeBlockId: UUID, reminderId: UUID, triggerTime: Int? = nil, message: String? = nil, soundEnabled: Bool? = nil, enabled: Bool? = nil) {
        guard let blockIndex = timeBlocks.firstIndex(where: { $0.id == timeBlockId }),
              let reminderIndex = timeBlocks[blockIndex].reminders.firstIndex(where: { $0.id == reminderId }) else {
            return
        }
        
        var block = timeBlocks[blockIndex]
        var reminder = block.reminders[reminderIndex]
        
        if let triggerTime = triggerTime {
            reminder.triggerTime = triggerTime
        }
        
        if let message = message {
            reminder.message = message
        }
        
        if let soundEnabled = soundEnabled {
            reminder.soundEnabled = soundEnabled
        }
        
        if let enabled = enabled {
            reminder.enabled = enabled
        }
        
        block.reminders[reminderIndex] = reminder
        timeBlocks[blockIndex] = block
        
        // 保存更改
        saveTimeBlocks()
    }
    
    // 删除时间块的提醒
    func deleteReminder(timeBlockId: UUID, reminderId: UUID) {
        guard let blockIndex = timeBlocks.firstIndex(where: { $0.id == timeBlockId }) else {
            return
        }
        
        var block = timeBlocks[blockIndex]
        block.reminders.removeAll { $0.id == reminderId }
        timeBlocks[blockIndex] = block
        
        // 保存更改
        saveTimeBlocks()
    }
    
    // 添加刷新方法 - 重置所有时间块的剩余时间
    func refreshAllTimeBlocks() {
        // 对每个时间块重置剩余时间
        for index in timeBlocks.indices {
            var block = timeBlocks[index]
            block.savedRemainingSeconds = block.duration * 60
            timeBlocks[index] = block
        }
        
        // 如果当前有活动的时间块，更新剩余时间
        if let currentIndex = currentBlockIndex {
            remainingSeconds = timeBlocks[currentIndex].duration * 60
        }
        
        // 重置今日统计
        dailyStats.reset()
        
        // 保存更改
        saveTimeBlocks()
        saveState()
        saveTimeStats()
        
        print("所有时间块已刷新")
    }
    
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
}

// 状态数据存储结构
struct TimeBlockStateData: Codable {
    let currentState: TimeBlockState
    let currentBlockIndex: Int?
    let remainingSeconds: Int
    let completedWorkBlocks: Int
    let isNextBreakLong: Bool
}

// 使TimeBlockState可编码
extension TimeBlockState: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        
        switch rawValue {
        case "idle":
            self = .idle
        case "active":
            self = .active
        case "paused":
            self = .paused
        case "finished":
            self = .finished
        default:
            self = .idle
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .idle:
            try container.encode("idle", forKey: .rawValue)
        case .active:
            try container.encode("active", forKey: .rawValue)
        case .paused:
            try container.encode("paused", forKey: .rawValue)
        case .finished:
            try container.encode("finished", forKey: .rawValue)
        }
    }
}

// 时间块颜色扩展，用于转换为实际的SwiftUI颜色
extension TimeBlockColor {
    // 获取对应的SwiftUI颜色
    func toColor() -> Color {
        switch self {
        case .red:
            return Color.red
        case .orange:
            return Color.orange
        case .yellow:
            return Color.yellow
        case .green:
            return Color.green
        case .blue:
            return Color.blue
        case .purple:
            return Color.purple
        case .gray:
            return Color.gray
        }
    }
    
    // 获取颜色名称
    func name() -> String {
        switch self {
        case .red:
            return "红色"
        case .orange:
            return "橙色"
        case .yellow:
            return "黄色"
        case .green:
            return "绿色"
        case .blue:
            return "蓝色"
        case .purple:
            return "紫色"
        case .gray:
            return "灰色"
        }
    }
    
    // 获取所有可用颜色
    static var allColors: [TimeBlockColor] {
        return [.red, .orange, .yellow, .green, .blue, .purple, .gray]
    }
}

// 时间块类型扩展
extension TimeBlockType {
    // 获取类型名称
    func name() -> String {
        switch self {
        case .work:
            return "工作"
        case .shortBreak:
            return "短休息"
        case .longBreak:
            return "长休息"
        }
    }
    
    // 获取所有可用类型
    static var allTypes: [TimeBlockType] {
        return [.work, .shortBreak, .longBreak]
    }
    
    // 获取图标名称（用于菜单栏显示）
    func iconName() -> NSImage.Name {
        switch self {
        case .work:
            return .work
        case .shortBreak:
            return .shortRest
        case .longBreak:
            return .longRest
        }
    }
}

// 时间格式化助手
extension TimeBlockManager {
    // 将剩余时间格式化为字符串
    func formattedTimeRemaining() -> String {
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// 应用程序设置管理
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // 时间相关设置
    @AppStorage("workIntervalLength") var workIntervalLength: Int = 25
    @AppStorage("shortRestIntervalLength") var shortRestIntervalLength: Int = 5
    @AppStorage("longRestIntervalLength") var longRestIntervalLength: Int = 15
    @AppStorage("workIntervalsInSet") var workIntervalsInSet: Int = 4
    
    // 界面设置
    @AppStorage("showTimerInMenuBar") var showTimerInMenuBar: Bool = true
    @AppStorage("stopAfterBreak") var stopAfterBreak: Bool = false
    
    // 开机自启动设置
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    
    // 声音设置
    @AppStorage("windupVolume") var windupVolume: Double = 1.0
    @AppStorage("dingVolume") var dingVolume: Double = 1.0
    @AppStorage("tickingVolume") var tickingVolume: Double = 1.0
    // 声音启用/禁用设置
    @AppStorage("isWindupEnabled") var isWindupEnabled: Bool = true
    @AppStorage("isDingEnabled") var isDingEnabled: Bool = true
    @AppStorage("isTickingEnabled") var isTickingEnabled: Bool = true
    
    // 隐藏设置
    @AppStorage("overrunTimeLimit") var overrunTimeLimit: Double = -60.0
    
    private init() {}
    
    // 将设置应用于时间块
    func applySettingsToTimeBlocks(timeBlocks: inout [TimeBlock]) {
        // 更新工作时间块的时长
        if let index = timeBlocks.firstIndex(where: { $0.type == .work }) {
            var block = timeBlocks[index]
            block.duration = workIntervalLength
            timeBlocks[index] = block
        }
        
        // 更新短休息时间块的时长
        if let index = timeBlocks.firstIndex(where: { $0.type == .shortBreak }) {
            var block = timeBlocks[index]
            block.duration = shortRestIntervalLength
            timeBlocks[index] = block
        }
        
        // 更新长休息时间块的时长
        if let index = timeBlocks.firstIndex(where: { $0.type == .longBreak }) {
            var block = timeBlocks[index]
            block.duration = longRestIntervalLength
            timeBlocks[index] = block
        }
    }
    
    // 将时间块的设置保存到AppStorage
    func saveTimeBlocksToSettings(timeBlocks: [TimeBlock]) {
        // 查找并保存工作时间块的时长
        if let workBlock = timeBlocks.first(where: { $0.type == .work }) {
            workIntervalLength = workBlock.duration
        }
        
        // 查找并保存短休息时间块的时长
        if let shortBreakBlock = timeBlocks.first(where: { $0.type == .shortBreak }) {
            shortRestIntervalLength = shortBreakBlock.duration
        }
        
        // 查找并保存长休息时间块的时长
        if let longBreakBlock = timeBlocks.first(where: { $0.type == .longBreak }) {
            longRestIntervalLength = longBreakBlock.duration
        }
    }
}

// 修改TimeBlockManager以使用AppSettings
extension TimeBlockManager {
    // 从AppSettings更新设置
    func updateFromAppSettings() {
        let settings = AppSettings.shared
        
        // 更新工作间隔集设置
        workIntervalsInSet = settings.workIntervalsInSet
        
        // 更新时间块时长
        settings.applySettingsToTimeBlocks(timeBlocks: &timeBlocks)
        
        // 保存更改
        saveTimeBlocks()
    }
    
    // 同步到AppSettings
    func syncToAppSettings() {
        let settings = AppSettings.shared
        
        // 更新AppSettings的工作间隔集
        settings.workIntervalsInSet = workIntervalsInSet
        
        // 将时间块设置保存到AppSettings
        settings.saveTimeBlocksToSettings(timeBlocks: timeBlocks)
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
