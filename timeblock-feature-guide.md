# TomatoBar时间块功能开发指南

## 功能需求概述

### 时间块管理功能
1. 允许用户自主添加多个时间块
2. 用户可在不同时间块之间自由切换
3. 从时间块A切换到时间块B时，B开始倒计时，A暂停计时
4. 支持配置最高15小时的时长
5. 支持用户修改和删除时间块
6. 提供时间块一键刷新功能

## 实现方案

### 1. 核心数据模型
```swift
struct TimeBlock: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var duration: TimeInterval  // 支持最高15小时 (54000秒)
    var isPaused: Bool = true
    var remainingTime: TimeInterval
    var category: String = "默认"
    
    init(name: String, durationMinutes: Double, category: String = "默认") {
        self.name = name
        self.category = category
        self.duration = min(durationMinutes * 60, 54000) // 最大15小时
        self.remainingTime = self.duration
    }
}
```

### 2. 状态管理重构
改变现有的状态管理机制，移除番茄钟相关状态：

```swift
class TBTimeBlockManager: ObservableObject {
    @Published var timeBlocks: [TimeBlock] = []
    @Published var activeTimeBlockId: UUID? = nil
    @Published var timeLeftString: String = ""
    
    private var timer: DispatchSourceTimer?
    private var finishTime: Date?
    private var timerFormatter = DateComponentsFormatter()
    
    // 状态管理方法
    func activateTimeBlock(_ id: UUID) 
    func pauseActiveTimeBlock()
    func resetTimeBlock(_ id: UUID)
    func resetAllTimeBlocks()
    
    // 时间块CRUD操作
    func addTimeBlock(name: String, durationMinutes: Double, category: String = "默认")
    func updateTimeBlock(id: UUID, name: String?, durationMinutes: Double?, category: String?)
    func deleteTimeBlock(id: UUID)
    
    // 计时器管理
    private func startTimer()
    private func pauseTimer() 
    private func stopTimer()
    private func updateTimeLeft()
    
    // 数据持久化
    private func saveTimeBlocks()
    private func loadTimeBlocks()
    
    // 通知管理
    private func sendTimeBlockCompletionNotification(timeBlock: TimeBlock)
}
```

### 3. 用户界面设计
创建时间块管理界面：

```swift
struct TimeBlocksView: View {
    @ObservedObject var timeBlockManager: TBTimeBlockManager
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedTimeBlock: TimeBlock?
    
    var body: some View {
        VStack {
            // 时间块列表
            List {
                ForEach(timeBlockManager.timeBlocks) { block in
                    TimeBlockRow(block: block, 
                                isActive: timeBlockManager.activeTimeBlockId == block.id,
                                onActivate: { timeBlockManager.activateTimeBlock(block.id) },
                                onEdit: { 
                                    selectedTimeBlock = block
                                    showingEditSheet = true
                                })
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        timeBlockManager.deleteTimeBlock(timeBlockManager.timeBlocks[index].id)
                    }
                }
            }
            
            // 控制按钮
            HStack {
                Button("添加时间块") {
                    showingAddSheet = true
                }
                
                Spacer()
                
                Button("重置所有") {
                    timeBlockManager.resetAllTimeBlocks()
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTimeBlockView(timeBlockManager: timeBlockManager)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let block = selectedTimeBlock {
                EditTimeBlockView(timeBlockManager: timeBlockManager, timeBlock: block)
            }
        }
    }
}
```

### 4. 菜单栏集成
重新设计状态栏显示：

```swift
class TBStatusItem: NSObject, NSApplicationDelegate {
    // 设置活动时间块的显示
    func updateMenuWithTimeBlocks(_ timeBlocks: [TimeBlock], activeId: UUID?) {
        let menu = NSMenu()
        
        // 添加时间块列表
        for block in timeBlocks {
            let isActive = activeId == block.id
            let formattedTime = formatTimeInterval(block.remainingTime)
            
            let blockItem = NSMenuItem(
                title: "\(block.name) (\(formattedTime))",
                action: #selector(selectTimeBlock(_:)),
                keyEquivalent: ""
            )
            blockItem.representedObject = block.id
            if isActive {
                blockItem.state = .on
            }
            menu.addItem(blockItem)
        }
        
        // 时间块管理和设置菜单项
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "管理时间块...", 
            action: #selector(showTimeBlockManager), 
            keyEquivalent: "")
        )
        menu.addItem(NSMenuItem(
            title: "设置...", 
            action: #selector(showSettings), 
            keyEquivalent: ",")
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "退出", 
            action: #selector(NSApplication.terminate(_:)), 
            keyEquivalent: "q")
        )
        
        statusItem?.menu = menu
    }
    
    // 更新状态栏图标和标题
    func updateStatusBarDisplay(activeBlock: TimeBlock?) {
        if let block = activeBlock {
            statusItem?.button?.title = formatTimeInterval(block.remainingTime)
            // 使用适合时间块的图标
            statusItem?.button?.image = NSImage(named: "TimeBlockActive")
        } else {
            statusItem?.button?.title = ""
            statusItem?.button?.image = NSImage(named: "TimeBlockIdle")
        }
    }
}
```

### 5. 数据持久化
保存和加载时间块数据：

```swift
// 在TBTimeBlockManager中
private func saveTimeBlocks() {
    do {
        let data = try JSONEncoder().encode(timeBlocks)
        UserDefaults.standard.set(data, forKey: "timeBlocks")
        
        // 保存活动时间块ID
        UserDefaults.standard.set(activeTimeBlockId?.uuidString, forKey: "activeTimeBlockId")
    } catch {
        print("无法保存时间块: \(error.localizedDescription)")
    }
}

private func loadTimeBlocks() {
    if let data = UserDefaults.standard.data(forKey: "timeBlocks") {
        do {
            timeBlocks = try JSONDecoder().decode([TimeBlock].self, from: data)
            
            // 加载活动时间块ID
            if let activeIdString = UserDefaults.standard.string(forKey: "activeTimeBlockId"),
               let activeId = UUID(uuidString: activeIdString) {
                activeTimeBlockId = activeId
            }
        } catch {
            print("无法加载时间块: \(error.localizedDescription)")
        }
    }
}
```

### 6. 通知系统
实现时间块完成通知：

```swift
private func sendTimeBlockCompletionNotification(timeBlock: TimeBlock) {
    let notification = UNMutableNotificationContent()
    notification.title = "时间块完成"
    notification.subtitle = timeBlock.name
    notification.body = "您已完成此时间块的计时"
    notification.sound = UNNotificationSound.default
    
    // 添加操作按钮
    notification.categoryIdentifier = "timeBlockCompleted"
    
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: notification,
        trigger: nil
    )
    
    UNUserNotificationCenter.current().add(request)
}
```

## 高级功能规划

### 1. 时间块分类
- 允许用户创建和管理时间块分类
- 支持按分类筛选和分组显示时间块
- 为不同分类设置不同的图标和颜色

### 2. 统计与报告
- 记录时间块使用历史
- 生成每日/每周/每月时间使用报告
- 提供时间利用效率分析

### 3. 系统集成
- 与macOS日历应用集成
- 支持从提醒事项导入任务
- 提供全局快捷键支持

### 4. 自定义外观
- 自定义状态栏显示样式
- 支持不同主题
- 允许用户自定义通知声音

## 实现步骤

1. 创建新的数据模型结构
2. 重构状态管理系统
3. 实现时间块CRUD操作
4. 设计并实现用户界面
5. 集成到菜单栏
6. 添加数据持久化功能
7. 实现通知系统
8. 添加高级功能 