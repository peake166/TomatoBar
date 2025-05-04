import KeyboardShortcuts
import SwiftState
import SwiftUI
import Combine

class TBTimer: ObservableObject {
    // 使用AppSettings来管理设置
    private var settings = AppSettings.shared
    
    // 添加时间块管理器
    @Published var timeBlockManager = TimeBlockManager()
    
    public let player = TBPlayer()
    private var notificationCenter = TBNotificationCenter()
    private var finishTime: Date?
    private var timerFormatter = DateComponentsFormatter()
    @Published var timeLeftString: String = ""
    @Published var timer: DispatchSourceTimer?
    
    // 保存订阅
    private var cancellables = Set<AnyCancellable>()

    init() {
        timerFormatter.unitsStyle = .positional
        timerFormatter.allowedUnits = [.hour, .minute, .second]
        timerFormatter.zeroFormattingBehavior = .pad

        KeyboardShortcuts.onKeyUp(for: .startStopTimer) { [weak self] in
            self?.toggleCurrentTimeBlock()
        }
        
        notificationCenter.setActionHandler(handler: onNotificationAction)

        let aem: NSAppleEventManager = NSAppleEventManager.shared()
        aem.setEventHandler(self,
                            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
                            forEventClass: AEEventClass(kInternetEventClass),
                            andEventID: AEEventID(kAEGetURL))
        
        // 同步设置和时间块
        syncSettingsAndTimeBlocks()
        
        // 设置时间块提醒观察器
        setupReminderObserver()
    }
    
    // 设置提醒观察器
    private func setupReminderObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReminderNotification(_:)),
            name: Notification.Name("TimeBlockReminderTriggered"),
            object: nil
        )
    }
    
    // 处理提醒通知
    @objc private func handleReminderNotification(_ notification: Foundation.Notification) {
        guard let userInfo = notification.userInfo,
              let reminder = userInfo["reminder"] as? TimeBlockReminder,
              let timeBlock = userInfo["timeBlock"] as? TimeBlock else {
            return
        }
        
        // 发送系统通知
        notificationCenter.sendTimeBlockReminder(
            timeBlockName: timeBlock.name,
            reminderMessage: reminder.message
        )
        
        // 如果启用了声音，播放提醒音效
        if reminder.soundEnabled {
            player.playDing()
        }
    }
    
    // 同步设置和时间块
    private func syncSettingsAndTimeBlocks() {
        // 将AppSettings应用到时间块管理器
        timeBlockManager.updateFromAppSettings()
        
        // 设置双向同步
        // 当设置发生变化时，更新时间块
        observeSettingsChanges()
        
        // 当时间块发生变化时，更新设置
        observeTimeBlockChanges()
    }
    
    // 观察设置变化
    private func observeSettingsChanges() {
        // 使用UserDefaults通知而不是直接观察@AppStorage属性
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main) // Debounce ensures we don't update too frequently
            .sink { [weak self] _ in
                // 当用户设置变化时更新时间块管理器状态
                // 确保在主线程执行更新 AppSettings 和 TimeBlockManager 的操作
                DispatchQueue.main.async {
                    self?.timeBlockManager.updateFromAppSettings()
                    // 可能还需要更新其他依赖于 settings 的部分，例如 Player 音量
                    self?.player.updateAllVolumes()
                }
            }
            .store(in: &cancellables)
            
        // 初始加载时也确保 TimeBlockManager 使用了最新的设置
        timeBlockManager.updateFromAppSettings()
        // 初始加载时也更新播放器音量
        player.updateAllVolumes()
    }
    
    // 观察时间块变化
    private func observeTimeBlockChanges() {
        // 正确使用Published属性的 projected value ($) 来获取 Publisher
        timeBlockManager.$timeBlocks
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main) // Debounce 同步操作
            .sink { [weak self] _ in
                // 当 timeBlocks 数组变化时，同步回 AppSettings
                // 确保在主线程执行
                 DispatchQueue.main.async {
                    self?.timeBlockManager.syncToAppSettings()
                 }
            }
            .store(in: &cancellables)
            
        // 初始加载时也进行一次同步，确保 AppSettings 反映了加载的 TimeBlocks
        // (或者在 TimeBlockManager 初始化加载后执行)
        // timeBlockManager.syncToAppSettings() // 考虑是否需要在这里初始同步

        // 观察 currentBlockIndex 的变化以进行状态恢复
         timeBlockManager.$currentBlockIndex
             .sink { [weak self] _ in
                 // 确保在主线程处理状态恢复逻辑
                 DispatchQueue.main.async {
                     // 直接访问 timeBlockManager 获取当前索引
                     self?.handleStateRestoration(currentIndex: self?.timeBlockManager.currentBlockIndex)
                 }
             }
             .store(in: &cancellables)
             
        // 初始状态也处理一次
        // 确保 handleStateRestoration 调用时传递的是正确的当前索引
        handleStateRestoration(currentIndex: timeBlockManager.currentBlockIndex)
    }
    
    // 处理状态恢复
    private func handleStateRestoration(currentIndex: Int?) {
        // 如果有活动的时间块索引，且当前没有运行的计时器，需要恢复计时器
        if let index = currentIndex, timer == nil {
            let state = timeBlockManager.currentState
            
            // 如果是活跃状态，启动计时器
            if state == .active {
                // 设置正确的图标
                if let currentBlock = timeBlockManager.currentTimeBlock {
                    TBStatusItem.shared.setIcon(name: currentBlock.type.iconName())
                    
                    // 如果是工作时间块，启动滴答声
                    if currentBlock.type == .work {
                        player.startTicking()
                    }
                }
                
                // 启动计时器
                startTimer()
            }
            // 如果是暂停状态，只更新显示
            else if state == .paused {
                if let currentBlock = timeBlockManager.currentTimeBlock {
                    TBStatusItem.shared.setIcon(name: currentBlock.type.iconName())
                }
                updateTimeLeft()
            }
        }
        // 如果没有活动的时间块索引，但有计时器在运行，需要停止计时器
        else if currentIndex == nil && timer != nil {
            stopTimer()
            player.stopTicking()
            TBStatusItem.shared.setIcon(name: .idle)
            TBStatusItem.shared.setTitle(title: nil)
        }
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                 withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.forKeyword(AEKeyword(keyDirectObject))?.stringValue else {
            print("url handling error: cannot get url")
            return
        }
        let url = URL(string: urlString)
        guard url != nil,
              let scheme = url!.scheme,
              let host = url!.host else {
            print("url handling error: cannot parse url")
            return
        }
        guard scheme.caseInsensitiveCompare("tomatobar") == .orderedSame else {
            print("url handling error: unknown scheme \(scheme)")
            return
        }
        switch host.lowercased() {
        case "startstop":
            toggleCurrentTimeBlock()
        case "pause":
            pauseCurrentTimeBlock()
        case "resume":
            resumeCurrentTimeBlock()
        case "skip":
            skipCurrentTimeBlock()
        default:
            print("url handling error: unknown command \(host)")
            return
        }
    }
    
    // 切换当前时间块状态（开始/暂停/继续）
    func toggleCurrentTimeBlock() {
        let state = timeBlockManager.currentState
        
        // 如果当前没有活动的时间块，启动默认的工作时间块
        if state == .idle {
            // 查找索引为0的时间块（默认工作时间块）并启动
            if !timeBlockManager.timeBlocks.isEmpty {
                startTimeBlock(index: 0)
            }
        } 
        // 如果当前正在运行，则暂停
        else if state == .active {
            pauseCurrentTimeBlock()
        }
        // 如果当前已暂停，则继续
        else if state == .paused {
            resumeCurrentTimeBlock()
        }
    }
    
    // 开始指定索引的时间块
    func startTimeBlock(index: Int) {
        // 停止当前的时间块（如果有）
        if timeBlockManager.currentBlockIndex != nil {
            stopCurrentTimeBlock()
        }
        
        // 取消所有待处理的通知
        notificationCenter.cancelAllPendingNotifications()
        
        // 启动新的时间块
        timeBlockManager.startTimeBlock(index: index)
        
        // 播放开始音效并设置图标
        if let currentBlock = timeBlockManager.currentTimeBlock {
            // 更新菜单栏图标
            updateMenuBarIcon()
            
            player.playWindup()
            
            // 如果是工作类型，播放滴答声
            if currentBlock.type == .work {
                player.startTicking()
            }
            
            // 发送时间块开始通知
            notificationCenter.sendTimeBlockStarted(name: currentBlock.name)
            
            // 为时间块中的每个提醒安排通知
            scheduleReminders(for: currentBlock)
        }
        
        // 启动计时器
        startTimer()
    }
    
    // 为时间块安排提醒通知
    private func scheduleReminders(for timeBlock: TimeBlock) {
        for reminder in timeBlock.reminders {
            if reminder.enabled {
                // 计算触发时间（相对于现在的秒数）
                let triggerInSeconds = TimeInterval(reminder.triggerTime)
                
                // 安排通知
                notificationCenter.scheduleTimeBlockReminder(
                    timeBlockName: timeBlock.name,
                    reminderMessage: reminder.message,
                    triggerInSeconds: triggerInSeconds
                )
            }
        }
    }
    
    // 暂停当前时间块
    func pauseCurrentTimeBlock() {
        guard timeBlockManager.currentState == .active else { return }
        
        // 保存当前时间块名称
        let blockName = timeBlockManager.currentTimeBlock?.name ?? ""
        
        timeBlockManager.pauseCurrentTimeBlock()
        
        // 停止滴答声
        player.stopTicking()
        
        // 如果有活动的计时器，停止它
        if timer != nil {
            stopTimer()
        }
        
        // 取消所有待处理的通知
        notificationCenter.cancelAllPendingNotifications()
        
        // 更新菜单栏图标
        updateMenuBarIcon()
        
        // 发送暂停通知
        notificationCenter.sendTimeBlockPaused(name: blockName)
    }
    
    // 恢复当前时间块
    func resumeCurrentTimeBlock() {
        guard timeBlockManager.currentState == .paused else { return }
        
        timeBlockManager.resumeCurrentTimeBlock()
        
        // 如果当前时间块是工作类型，恢复滴答声
        if let currentBlock = timeBlockManager.currentTimeBlock, currentBlock.type == .work {
            player.startTicking()
            
            // 重新安排提醒通知
            scheduleReminders(for: currentBlock)
        }
        
        // 更新菜单栏图标
        updateMenuBarIcon()
        
        // 重新启动计时器
        startTimer()
    }
    
    // 停止当前时间块
    func stopCurrentTimeBlock() {
        // 保存当前剩余时间到时间块中
        if let index = timeBlockManager.currentBlockIndex {
            var block = timeBlockManager.timeBlocks[index]
            block.savedRemainingSeconds = timeBlockManager.remainingSeconds
            timeBlockManager.timeBlocks[index] = block
            
            // 确保保存更改
            timeBlockManager.saveTimeBlocks()
        }
        
        // 停止滴答声
        player.stopTicking()
        
        // 重置时间块管理器
        timeBlockManager.reset()
        
        // 停止计时器
        if timer != nil {
            stopTimer()
        }
        
        // 取消所有待处理的通知
        notificationCenter.cancelAllPendingNotifications()
        
        // 设置为空闲图标
        TBStatusItem.shared.setIcon(name: .idle)
        TBStatusItem.shared.setTitle(title: nil)
    }
    
    // 跳过当前时间块
    func skipCurrentTimeBlock() {
        if let currentBlock = timeBlockManager.currentTimeBlock {
            // 记录当前类型
            let currentType = currentBlock.type
            
            // 完成当前时间块
            timeBlockManager.finishCurrentTimeBlock()
            
            // 停止滴答声
            player.stopTicking()
            
            // 停止计时器
            if timer != nil {
                stopTimer()
            }
            
            // 如果跳过的是工作时间块，自动开始短休息
            if currentType == .work {
                // 找到短休息时间块索引
                if let breakIndex = timeBlockManager.timeBlocks.firstIndex(where: { $0.type == .shortBreak }) {
                    startTimeBlock(index: breakIndex)
                }
            }
            // 如果跳过的是休息时间块，自动开始工作
            else if currentType == .shortBreak || currentType == .longBreak {
                // 如果需要停止，直接停止
                if settings.stopAfterBreak {
                    stopCurrentTimeBlock()
                } else {
                    // 找到工作时间块索引
                    if let workIndex = timeBlockManager.timeBlocks.firstIndex(where: { $0.type == .work }) {
                        startTimeBlock(index: workIndex)
                    }
                }
            }
        }
    }

    // 更新显示的时间
    func updateTimeLeft() {
        timeLeftString = timeBlockManager.formattedTimeRemaining()
        
        if timer != nil, settings.showTimerInMenuBar {
            TBStatusItem.shared.setTitle(title: timeLeftString)
        } else {
            TBStatusItem.shared.setTitle(title: nil)
        }
    }
    
    // 更新菜单栏图标
    private func updateMenuBarIcon() {
        if let currentBlock = timeBlockManager.currentTimeBlock {
            // 根据当前活动的时间块类型和状态设置状态栏图标
            let iconName = currentBlock.type.iconName()
            TBStatusItem.shared.setIcon(name: iconName)
            
            // 更新时间显示
            updateTimeLeft()
            
            // 如果处于暂停状态，在标题前添加暂停标识
            if timeBlockManager.currentState == .paused {
                // 如果已经显示了时间，在前面添加暂停标识
                if settings.showTimerInMenuBar {
                    let pausedTimeString = "⏸︎ " + timeLeftString
                    TBStatusItem.shared.setTitle(title: pausedTimeString)
                } else {
                    // 如果没有显示时间，只显示暂停标识
                    TBStatusItem.shared.setTitle(title: "⏸︎")
                }
            }
        } else {
            // 如果没有活动的时间块，设置为空闲图标
            TBStatusItem.shared.setIcon(name: .idle)
            TBStatusItem.shared.setTitle(title: nil)
        }
    }

    // 启动计时器
    private func startTimer() {
        finishTime = Date().addingTimeInterval(TimeInterval(timeBlockManager.remainingSeconds))

        let queue = DispatchQueue(label: "Timer")
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer!.schedule(deadline: .now(), repeating: .seconds(1), leeway: .never)
        timer!.setEventHandler(handler: onTimerTick)
        timer!.setCancelHandler(handler: onTimerCancel)
        timer!.resume()
    }

    // 停止计时器
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    // 计时器滴答事件
    private func onTimerTick() {
        /* Cannot publish updates from background thread */
        DispatchQueue.main.async { [self] in
            // 更新时间块管理器的时间
            timeBlockManager.updateTime()
            
            // 更新显示
            updateTimeLeft()
            
            // 手动触发UI更新，确保所有时间块的剩余时间显示都会更新
            // 因为SwiftUI会监听这些属性的变化，所以这里使用objectWillChange来触发视图更新
            timeBlockManager.objectWillChange.send()
            
            // 检查时间块是否完成
            if timeBlockManager.currentState == .finished {
                handleTimeBlockFinished()
            }
        }
    }

    // 处理时间块完成事件
    private func handleTimeBlockFinished() {
        // 没有活动的时间块，意味着刚刚完成了一个时间块
        if timeBlockManager.currentBlockIndex == nil {
            // 播放完成音效
            player.playDing()
            
            // 停止滴答声
            player.stopTicking()
            
            // 更新菜单栏图标为空闲状态
            TBStatusItem.shared.setIcon(name: .idle)
            
            // 取得刚刚完成的时间块类型和名称
            if let completedBlock = timeBlockManager.timeBlocks.first(where: { $0.isActive }) {
                // 发送时间块完成通知
                notificationCenter.sendTimeBlockFinished(name: completedBlock.name)
                
                // 取消所有待处理的通知
                notificationCenter.cancelAllPendingNotifications()
            }
            
            // 取得刚刚完成的时间块类型
            if let lastCompletedBlockType = getLastCompletedBlockType() {
                // 根据完成的时间块类型决定下一步操作
                if lastCompletedBlockType == .work {
                    // 工作完成后，开始休息
                    startRestAfterWork()
                } else {
                    // 休息完成后，根据设置决定是否自动开始工作
                    handleRestFinished()
                }
            }
        }
    }
    
    // 获取刚完成的时间块类型（通过分析状态）
    private func getLastCompletedBlockType() -> TimeBlockType? {
        // 查看是否需要长休息
        if timeBlockManager.isNextBreakLong {
            return .work
        } 
        // 如果刚完成了工作时间块
        else if timeBlockManager.completedWorkBlocks > 0 {
            return .work
        }
        // 如果刚完成了休息时间块
        else {
            return .shortBreak
        }
    }
    
    // 工作完成后开始休息
    private func startRestAfterWork() {
        // 发送工作完成通知
        notificationCenter.send(
            title: NSLocalizedString("TBTimer.onRestStart.title", comment: "Time's up title"),
            body: timeBlockManager.isNextBreakLong 
                  ? NSLocalizedString("TBTimer.onRestStart.long.body", comment: "Long break body")
                  : NSLocalizedString("TBTimer.onRestStart.short.body", comment: "Short break body"),
            category: .restStarted
        )
        
        // 查找并启动适当的休息时间块
        let restType: TimeBlockType = timeBlockManager.isNextBreakLong ? .longBreak : .shortBreak
        if let restIndex = timeBlockManager.timeBlocks.firstIndex(where: { $0.type == restType }) {
            startTimeBlock(index: restIndex)
        }
    }
    
    // 处理休息完成
    private func handleRestFinished() {
        // 发送休息完成通知
        notificationCenter.send(
            title: NSLocalizedString("TBTimer.onRestFinish.title", comment: "Break is over title"),
            body: NSLocalizedString("TBTimer.onRestFinish.body", comment: "Break is over body"),
            category: .restFinished
        )
        
        // 根据设置决定是否自动开始工作
        if !settings.stopAfterBreak {
            // 查找工作时间块
            if let workIndex = timeBlockManager.timeBlocks.firstIndex(where: { $0.type == .work }) {
                startTimeBlock(index: workIndex)
            }
        } else {
            // 停止计时器
            if timer != nil {
                stopTimer()
            }
            
            // 设置为空闲图标
            TBStatusItem.shared.setIcon(name: .idle)
        }
    }

    // 计时器取消事件
    private func onTimerCancel() {
        DispatchQueue.main.async { [self] in
            updateTimeLeft()
        }
    }

    // 通知操作处理
    private func onNotificationAction(action: TBNotification.Action) {
        switch action {
        case .skipRest:
            skipCurrentTimeBlock()
        case .pauseTimeBlock:
            pauseCurrentTimeBlock()
        case .resumeTimeBlock:
            resumeCurrentTimeBlock()
        case .skipTimeBlock:
            skipCurrentTimeBlock()
        case .dismissReminder:
            // 忽略提醒，不需要执行任何操作
            break
        }
    }
    
    // 添加自定义提醒到时间块
    func addReminderToTimeBlock(timeBlockIndex: Int, triggerTime: Int, message: String, soundEnabled: Bool = true) {
        guard timeBlockIndex >= 0, timeBlockIndex < timeBlockManager.timeBlocks.count else { return }
        
        let timeBlock = timeBlockManager.timeBlocks[timeBlockIndex]
        timeBlockManager.addReminderToTimeBlock(
            timeBlockId: timeBlock.id,
            triggerTime: triggerTime,
            message: message,
            soundEnabled: soundEnabled
        )
        
        // 如果这个时间块当前是活动的，为这个新提醒安排通知
        if timeBlockManager.currentBlockIndex == timeBlockIndex && timeBlockManager.currentState == .active {
            let remainingSeconds = timeBlockManager.remainingSeconds
            let totalSeconds = timeBlock.duration * 60
            let elapsedSeconds = totalSeconds - remainingSeconds
            
            // 如果触发时间在未来
            if triggerTime > elapsedSeconds {
                let secondsUntilTrigger = TimeInterval(triggerTime - elapsedSeconds)
                notificationCenter.scheduleTimeBlockReminder(
                    timeBlockName: timeBlock.name,
                    reminderMessage: message,
                    triggerInSeconds: secondsUntilTrigger
                )
            }
        }
    }
}
