import KeyboardShortcuts
import SwiftUI
import ServiceManagement

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
}

// 时间块行组件 - 显示单个时间块
private struct TimeBlockRow: View {
    var timeBlock: TimeBlock
    var currentState: TimeBlockState
    var remainingSeconds: Int?
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onManageReminders: () -> Void
    var onPauseResume: () -> Void
    
    @State private var isHovering = false
    
    var isActive: Bool {
        timeBlock.isActive
    }
    
    var body: some View {
        HStack {
            // 时间块颜色指示器
            Circle()
                .fill(timeBlock.color.toColor())
                .frame(width: 12, height: 12)
            
            // 时间块信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // 时间块名称
                    Text(timeBlock.name)
                        .fontWeight(isActive ? .bold : .regular)
                        .foregroundColor(isActive ? .primary : .secondary)
                    
                    Spacer()
                    
                    // 显示时间信息（活动状态显示剩余时间，非活动状态显示总时长）
                    HStack(spacing: 4) {
                        Image(systemName: isActive ? "timer" : "clock")
                            .font(.caption2)
                            .foregroundColor(isActive ? (currentState == .active ? .green : .orange) : .secondary)
                        
                        // 修改逻辑：先检查是否有剩余时间，如果有就显示，无论是否是活动时间块
                        if let seconds = remainingSeconds {
                            Text(formatRemainingTime(seconds))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(isActive ? (currentState == .active ? .green : .orange) : .blue)
                                .fontWeight(.medium)
                        } else {
                            // 如果没有剩余时间，显示总时长
                            let formattedDuration = formatDuration(timeBlock.duration)
                            Text(formattedDuration)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 时间块类型标签
                HStack(spacing: 8) {
                    Text(timeBlock.type.name())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    
                    // 如果有提醒，显示提醒图标
                    if !timeBlock.reminders.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                            Text("\(timeBlock.reminders.count)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 如果是当前活动的时间块，显示状态指示器
                    if isActive {
                        StatusIndicatorView(status: currentState)
                    }
                }
            }
            
            // 操作按钮（鼠标悬停时显示）
            if isHovering {
                HStack(spacing: 8) {
                    // 编辑按钮
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    // 删除按钮
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    // 提醒管理按钮
                    Button(action: onManageReminders) {
                        Image(systemName: "bell")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovering in
            self.isHovering = isHovering
        }
        .padding(.vertical, 4)
    }
    
    // 格式化剩余时间显示
    private func formatRemainingTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    // 格式化持续时间显示
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, mins)
        } else {
            return String(format: "%02d:00", mins)
        }
    }
}

// 时间块编辑视图
private struct TimeBlockEditView: View {
    @Binding var timeBlock: TimeBlock
    var onSave: (Int, Int) -> Void
    var onCancel: () -> Void
    
    // 添加小时和分钟的状态变量
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    
    // 初始化函数
    init(timeBlock: Binding<TimeBlock>, onSave: @escaping (Int, Int) -> Void, onCancel: @escaping () -> Void) {
        self._timeBlock = timeBlock
        self.onSave = onSave
        self.onCancel = onCancel
        
        // 首先检查是否有已保存的剩余时间
        if let savedSeconds = timeBlock.wrappedValue.savedRemainingSeconds {
            // 如果有已保存的剩余时间，使用它来初始化小时和分钟
            let totalSeconds = savedSeconds
            let initialHours = totalSeconds / 3600
            let initialMinutes = (totalSeconds % 3600) / 60
            
            // 打印调试信息
            print("使用已保存的剩余时间初始化: \(savedSeconds)秒, \(initialHours)小时 \(initialMinutes)分钟")
            
            self._hours = State(initialValue: initialHours)
            self._minutes = State(initialValue: initialMinutes)
        } else {
            // 没有已保存的剩余时间，使用持续时间（分钟）
            let totalMinutes = timeBlock.wrappedValue.duration
            let initialHours = totalMinutes / 60
            let initialMinutes = totalMinutes % 60
            
            // 打印调试信息
            print("使用持续时间初始化: \(totalMinutes)分钟, \(initialHours)小时 \(initialMinutes)分钟")
            
            self._hours = State(initialValue: initialHours)
            self._minutes = State(initialValue: initialMinutes)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(timeBlock.id == UUID() ? "添加时间块" : "编辑时间块")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("名称")
                    .font(.subheadline)
                
                TextField("输入名称", text: $timeBlock.name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("时长")
                    .font(.subheadline)
                
                HStack {
                    // 小时设置
                    VStack(alignment: .leading) {
                        Text("小时")
                            .font(.caption)
                        
                        Stepper(value: $hours, in: 0...24) {
                            HStack {
                                Text("\(hours)")
                                    .frame(width: 30, alignment: .leading)
                                Text("小时")
                                    .font(.caption)
                            }
                        }
                        .onChange(of: hours) { _ in
                            updateTimeBlockDuration()
                        }
                    }
                    
                    // 分钟设置
                    VStack(alignment: .leading) {
                        Text("分钟")
                            .font(.caption)
                        
                        Stepper(value: $minutes, in: 0...59) {
                            HStack {
                                Text("\(minutes)")
                                    .frame(width: 30, alignment: .leading)
                                Text("分钟")
                                    .font(.caption)
                            }
                        }
                        .onChange(of: minutes) { _ in
                            updateTimeBlockDuration()
                        }
                    }
                }
                
                // 总时间显示
                Text("总时间: \(formatTime(hours: hours, minutes: minutes))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("类型")
                    .font(.subheadline)
                
                Picker("类型", selection: $timeBlock.type) {
                    ForEach(TimeBlockType.allTypes, id: \.self) { type in
                        Text(type.name()).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("颜色")
                    .font(.subheadline)
                
                HStack {
                    ForEach(TimeBlockColor.allColors, id: \.self) { color in
                        Circle()
                            .fill(color.toColor())
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(timeBlock.color == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                timeBlock.color = color
                            }
                            .padding(.horizontal, 2)
                    }
                }
            }
            
            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("保存") {
                    // 确保在保存前更新时间块的持续时间
                    updateTimeBlockDuration()
                    onSave(hours, minutes)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 300)
    }
    
    // 更新时间块时长
    private func updateTimeBlockDuration() {
        // 将小时和分钟合并为总分钟数
        let totalMinutes = hours * 60 + minutes
        timeBlock.duration = totalMinutes
        
        // 同时更新 savedRemainingSeconds 为对应的秒数
        let totalSeconds = hours * 3600 + minutes * 60
        timeBlock.savedRemainingSeconds = totalSeconds
        
        // 打印调试信息
        print("更新时间块持续时间: \(totalMinutes)分钟, 转换为: \(totalSeconds)秒")
    }
    
    // 格式化时间显示
    private func formatTime(hours: Int, minutes: Int) -> String {
        if hours > 0 {
            return "\(hours)小时 \(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// 状态指示器视图
private struct StatusIndicatorView: View {
    var status: TimeBlockState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .idle:
            return Color.gray
        case .active:
            return Color.green
        case .paused:
            return Color.orange
        case .finished:
            return Color.blue
        }
    }
    
    private var statusText: String {
        switch status {
        case .idle:
            return "空闲"
        case .active:
            return "进行中"
        case .paused:
            return "已暂停"
        case .finished:
            return "已完成"
        }
    }
}

// 简单的时间块统计视图
private struct TimeBlockStatsView: View {
    var timeBlocks: [TimeBlock]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("统计信息")
                .font(.headline)
                .padding(.bottom, 4)
            
            Group {
                HStack {
                    Text("总时间块数量:")
                    Spacer()
                    Text("\(timeBlocks.count)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("工作时间块:")
                    Spacer()
                    Text("\(timeBlocks.filter { $0.type == .work }.count)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("休息时间块:")
                    Spacer()
                    Text("\(timeBlocks.filter { $0.type == .shortBreak || $0.type == .longBreak }.count)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("总计划时间:")
                    Spacer()
                    Text("\(totalDuration) 分钟")
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    private var totalDuration: Int {
        timeBlocks.reduce(0) { $0 + $1.duration }
    }
}

// 时间块管理视图
private struct TimeBlocksView: View {
    @EnvironmentObject var timer: TBTimer
    @State private var isEditing = false
    @State private var editingBlock = TimeBlock.createDefault(type: .work)
    @State private var isAddingNew = false
    @State private var showDeleteAlert = false
    @State private var blockToDelete: UUID? = nil
    @State private var showStats = false
    
    var body: some View {
        VStack(spacing: 10) {
            // 添加今日工作目标时间组件
            TodayWorkTargetView(timeBlockManager: timer.timeBlockManager)
            
            // 状态指示
            if let currentBlock = timer.timeBlockManager.currentTimeBlock {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前时间块")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(currentBlock.name)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    StatusIndicatorView(status: timer.timeBlockManager.currentState)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            
            // 添加刷新按钮和统计切换
            HStack {
                Button(action: {
                    // 执行刷新操作
                    timer.timeBlockManager.refreshAllTimeBlocks()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新时间")
                    }
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
                
                Spacer()
                
                Button(action: {
                    showStats.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showStats ? "chart.bar.xaxis" : "chart.bar.xaxis")
                            .foregroundColor(showStats ? .blue : .gray)
                        Text(showStats ? "隐藏统计" : "显示统计")
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            
            // 时间块列表
            List {
                ForEach(timer.timeBlockManager.timeBlocks) { block in
                    TimeBlockRow(
                        timeBlock: block,
                        currentState: timer.timeBlockManager.currentState,
                        remainingSeconds: timer.timeBlockManager.getRemainingSeconds(for: block.id),
                        onTap: {
                            // 获取当前块的索引
                            let blockIndex = timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == block.id })
                            let isCurrentBlock = timer.timeBlockManager.currentBlockIndex == blockIndex
                            
                            // 根据当前状态执行不同操作
                            if timer.timeBlockManager.currentState == .idle {
                                // 如果空闲状态，启动时间块
                                if let index = blockIndex {
                                    timer.startTimeBlock(index: index)
                                }
                            } 
                            else if isCurrentBlock {
                                // 如果是当前活动的时间块
                                if timer.timeBlockManager.currentState == .active {
                                    // 正在运行，点击暂停
                                    timer.pauseCurrentTimeBlock()
                                } else if timer.timeBlockManager.currentState == .paused {
                                    // 已暂停，点击继续
                                    timer.resumeCurrentTimeBlock()
                                }
                            }
                            else {
                                // 点击了不同于当前活动的时间块，切换到该时间块
                                // 先停止当前的，再启动新的
                                timer.stopCurrentTimeBlock()
                                if let index = blockIndex {
                                    timer.startTimeBlock(index: index)
                                }
                            }
                        },
                        onEdit: {
                            editingBlock = block
                            isEditing = true
                            isAddingNew = false
                        },
                        onDelete: {
                            blockToDelete = block.id
                            showDeleteAlert = true
                        },
                        onManageReminders: {
                            // Implementation needed
                        },
                        onPauseResume: {
                            // 这个回调现在不再使用，但为兼容性暂时保留
                            // 原有逻辑已移到onTap处理
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
                    .listRowBackground(Color.clear)
                }
                .onMove { source, destination in
                    timer.timeBlockManager.moveTimeBlock(from: source, to: destination)
                }
            }
            .listStyle(PlainListStyle())
            
            // 显示统计信息（如果启用）
            if showStats {
                TimeBlockStatsView(timeBlocks: timer.timeBlockManager.timeBlocks)
                    .padding(.top, 4)
            }
            
            // 添加新时间块按钮
            Button(action: {
                newTimeBlock()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("添加新时间块")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            
            // 底部分隔线
            Divider()
                .padding(.bottom, 8)
                
            // 底部状态栏
            if let currentIndex = timer.timeBlockManager.currentBlockIndex,
               timer.timeBlockManager.timeBlocks.indices.contains(currentIndex) {
                let currentBlock = timer.timeBlockManager.timeBlocks[currentIndex]
                
                HStack {
                    Circle()
                        .fill(currentBlock.type == .work ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text(timer.timeBlockManager.currentState == .active ? "正在进行" : "已暂停")
                        .font(.caption)
                    
                    Spacer()
                    
                    Text(timer.timeLeftString)
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
        }
        .padding()
        
        // 时间块编辑表单
        .sheet(isPresented: $isEditing) {
            TimeBlockEditView(
                timeBlock: $editingBlock,
                onSave: { hours, minutes in
                    // 计算新的总分钟数和总秒数
                    let totalMinutes = hours * 60 + minutes
                    let totalSeconds = hours * 3600 + minutes * 60
                    
                    if isAddingNew {
                        // 添加新时间块
                        var newBlock = TimeBlock(
                            name: editingBlock.name,
                            duration: totalMinutes,
                            type: editingBlock.type,
                            color: editingBlock.color
                        )
                        newBlock.savedRemainingSeconds = totalSeconds
                        
                        // 添加新时间块
                        timer.timeBlockManager.timeBlocks.append(newBlock)
                        timer.timeBlockManager.saveTimeBlocks()
                    } else {
                        // 更新现有时间块
                        if let index = timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == editingBlock.id }) {
                            var updatedBlock = timer.timeBlockManager.timeBlocks[index]
                            
                            // 手动更新时间块的 duration 和 savedRemainingSeconds
                            updatedBlock.duration = totalMinutes
                            updatedBlock.savedRemainingSeconds = totalSeconds
                            updatedBlock.name = editingBlock.name
                            updatedBlock.type = editingBlock.type
                            updatedBlock.color = editingBlock.color
                            
                            // 将更新后的时间块放回数组中
                            timer.timeBlockManager.timeBlocks[index] = updatedBlock
                            
                            // 如果这是当前活动的时间块，更新 remainingSeconds
                            if timer.timeBlockManager.currentBlockIndex == index {
                                timer.timeBlockManager.remainingSeconds = totalSeconds
                                timer.updateTimeLeft()
                            }
                        }
                        
                        // 保存更改
                        timer.timeBlockManager.saveTimeBlocks()
                    }
                    
                    // 重要：手动触发对象变更通知，确保 UI 更新
                    timer.timeBlockManager.objectWillChange.send()
                    
                    isEditing = false
                    isAddingNew = false
                },
                onCancel: {
                    isEditing = false
                    isAddingNew = false
                }
            )
        }
        
        // 删除确认对话框
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("确认删除"),
                message: Text("确定要删除这个时间块吗？此操作无法撤销。"),
                primaryButton: .destructive(Text("删除")) {
                    if let id = blockToDelete {
                        timer.timeBlockManager.deleteTimeBlock(id: id)
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    // 添加新时间块
    private func newTimeBlock() {
        editingBlock = TimeBlock.createDefault(type: .work)
        isEditing = true
        isAddingNew = true
    }
}

// 修改现有的SettingsView以使用AppSettings
private struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @EnvironmentObject var timer: TBTimer

    var body: some View {
        VStack {
            KeyboardShortcuts.Recorder(for: .startStopTimer) {
                Text(NSLocalizedString("SettingsView.shortcut.label",
                                       comment: "Shortcut label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $settings.showTimerInMenuBar) {
                Text(NSLocalizedString("SettingsView.showTimerInMenuBar.label",
                                       comment: "Show timer in menu bar label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
                .onChange(of: settings.showTimerInMenuBar) {
                    timer.updateTimeLeft()
                }
            
            // 添加开机自启动选项
            Toggle(isOn: Binding<Bool>(
                get: { settings.launchAtLogin },
                set: { newValue in
                    // 尝试设置登录项
                    let success = setLaunchAtLogin(newValue)
                    // 只有成功时才更新设置
                    if success {
                        settings.launchAtLogin = newValue
                    }
                }
            )) {
                Text(NSLocalizedString("SettingsView.launchAtLogin.label",
                                     comment: "Launch at login label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            
            Divider()
                .padding(.vertical, 8)
            
            // 添加退出按钮
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                        .foregroundColor(.red)
                    Text("退出应用")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
        .onAppear {
            // 当视图出现时，同步系统状态
            syncLaunchAtLoginState()
        }
    }
    
    // 设置开机自启动
    private func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            // 使用现代API (macOS 13+)
            do {
                if enabled {
                    if SMAppService.mainApp.status == .enabled {
                        return true // 已经启用，不需要操作
                    }
                    try SMAppService.mainApp.register()
                } else {
                    if SMAppService.mainApp.status == .notRegistered {
                        return true // 已经禁用，不需要操作
                    }
                    try SMAppService.mainApp.unregister()
                }
                return true
            } catch {
                print("设置开机自启动失败: \(error.localizedDescription)")
                return false
            }
        } else {
            // 旧版macOS使用传统API
            return SMLoginItemSetEnabled(Bundle.main.bundleIdentifier! as CFString, enabled)
        }
        #else
        return false
        #endif
    }
    
    // 同步开机自启动状态
    private func syncLaunchAtLoginState() {
        #if os(macOS)
        let currentlyEnabled: Bool
        if #available(macOS 13.0, *) {
            currentlyEnabled = SMAppService.mainApp.status == .enabled
        } else {
            // 旧版API检查方法不精确，我们依赖存储的设置值
            currentlyEnabled = settings.launchAtLogin
        }
        
        if currentlyEnabled != settings.launchAtLogin {
            // 如果不一致，以系统实际状态为准
            settings.launchAtLogin = currentlyEnabled
        }
        #endif
    }
}

// 修改现有的SoundsView以使用AppSettings
private struct SoundsView: View {
    @ObservedObject var settings = AppSettings.shared

    private var columns = [
        GridItem(.flexible()),
        GridItem(.fixed(110))
    ]

    var body: some View {
        VStack(spacing: 12) {
            // 计时开始提示音设置
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(NSLocalizedString("SoundsView.isWindupEnabled.label", comment: "Windup label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Toggle("", isOn: $settings.isWindupEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                HStack {
                    Text("音量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    VolumeSlider(volume: $settings.windupVolume)
                        .disabled(!settings.isWindupEnabled)
                        .opacity(settings.isWindupEnabled ? 1.0 : 0.5)
                        .frame(width: 120)
                }
                .padding(.leading, 10)
            }
            
            Divider()
            
            // 计时结束提示音设置
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(NSLocalizedString("SoundsView.isDingEnabled.label", comment: "Ding label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Toggle("", isOn: $settings.isDingEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                HStack {
                    Text("音量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    VolumeSlider(volume: $settings.dingVolume)
                        .disabled(!settings.isDingEnabled)
                        .opacity(settings.isDingEnabled ? 1.0 : 0.5)
                        .frame(width: 120)
                }
                .padding(.leading, 10)
            }
            
            Divider()
            
            // 计时进行中秒针声设置
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(NSLocalizedString("SoundsView.isTickingEnabled.label", comment: "Ticking label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Toggle("", isOn: $settings.isTickingEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                HStack {
                    Text("音量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    VolumeSlider(volume: $settings.tickingVolume)
                        .disabled(!settings.isTickingEnabled)
                        .opacity(settings.isTickingEnabled ? 1.0 : 0.5)
                        .frame(width: 120)
                }
                .padding(.leading, 10)
            }
        }
        .padding()
        Spacer().frame(minHeight: 0)
    }
}

private struct VolumeSlider: View {
    @Binding var volume: Double

    var body: some View {
        Slider(value: $volume, in: 0...2) {
            Text(String(format: "%.1f", volume))
        }.gesture(TapGesture(count: 2).onEnded({
            volume = 1.0
        }))
    }
}

private enum ChildView {
    case timeBlocks, settings, sounds
}

// 时间块提醒管理视图
private struct TimeBlockRemindersView: View {
    var timeBlock: TimeBlock
    var onAddReminder: (Int, String, Bool) -> Void
    var onUpdateReminder: (UUID, Int, String, Bool, Bool) -> Void
    var onDeleteReminder: (UUID) -> Void
    var onDismiss: () -> Void
    
    @State private var showAddReminderSheet = false
    @State private var editingReminder: TimeBlockReminder?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(timeBlock.name) 的提醒")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            
            if timeBlock.reminders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("没有设置提醒")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(timeBlock.reminders) { reminder in
                        ReminderRow(
                            reminder: reminder,
                            timeBlockDuration: timeBlock.duration,
                            onEdit: { editingReminder = reminder },
                            onToggle: { enabled in
                                onUpdateReminder(
                                    reminder.id,
                                    reminder.triggerTime,
                                    reminder.message,
                                    reminder.soundEnabled,
                                    enabled
                                )
                            },
                            onDelete: { onDeleteReminder(reminder.id) }
                        )
                    }
                }
                .listStyle(.plain)
            }
            
            Button(action: { showAddReminderSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加提醒")
                }
                .frame(maxWidth: .infinity)
                    }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(width: 320, height: 400)
        .sheet(isPresented: $showAddReminderSheet) {
            ReminderEditView(
                timeBlockDuration: timeBlock.duration,
                reminder: nil,
                onSave: { triggerTime, message, soundEnabled in
                    onAddReminder(triggerTime, message, soundEnabled)
                    showAddReminderSheet = false
                },
                onCancel: { showAddReminderSheet = false }
            )
        }
        .sheet(item: $editingReminder) { reminder in
            ReminderEditView(
                timeBlockDuration: timeBlock.duration,
                reminder: reminder,
                onSave: { triggerTime, message, soundEnabled in
                    onUpdateReminder(
                        reminder.id,
                        triggerTime,
                        message,
                        soundEnabled,
                        reminder.enabled
                    )
                    editingReminder = nil
                },
                onCancel: { editingReminder = nil }
            )
        }
    }
}

// 单个提醒行视图
private struct ReminderRow: View {
    var reminder: TimeBlockReminder
    var timeBlockDuration: Int
    var onEdit: () -> Void
    var onToggle: (Bool) -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { reminder.enabled },
                set: { onToggle($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatTriggerTime(reminder.triggerTime, timeBlockDuration * 60))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(reminder.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .toggleStyle(.switch)
            
            Spacer()
            
            if reminder.soundEnabled {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    // 格式化触发时间
    private func formatTriggerTime(_ seconds: Int, _ totalSeconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        
        if seconds == 0 {
            return "开始时"
        } else if seconds >= totalSeconds {
            return "结束时"
        } else {
            return String(format: "%d分%02d秒后", minutes, remainingSeconds)
        }
    }
}

// 提醒编辑视图
private struct ReminderEditView: View {
    var timeBlockDuration: Int
    var reminder: TimeBlockReminder?
    var onSave: (Int, String, Bool) -> Void
    var onCancel: () -> Void
    
    @State private var triggerMinutes: Int
    @State private var triggerSeconds: Int
    @State private var message: String
    @State private var soundEnabled: Bool
    
    init(timeBlockDuration: Int, reminder: TimeBlockReminder?, onSave: @escaping (Int, String, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.timeBlockDuration = timeBlockDuration
        self.reminder = reminder
        self.onSave = onSave
        self.onCancel = onCancel
        
        // 初始化状态变量
        if let reminder = reminder {
            _triggerMinutes = State(initialValue: reminder.triggerTime / 60)
            _triggerSeconds = State(initialValue: reminder.triggerTime % 60)
            _message = State(initialValue: reminder.message)
            _soundEnabled = State(initialValue: reminder.soundEnabled)
                } else {
            // 默认值为工作时间的一半
            _triggerMinutes = State(initialValue: timeBlockDuration / 2)
            _triggerSeconds = State(initialValue: 0)
            _message = State(initialValue: "继续保持！")
            _soundEnabled = State(initialValue: true)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(reminder == nil ? "添加提醒" : "编辑提醒")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("触发时间")
                    .font(.subheadline)
                
                HStack {
                    Stepper(value: $triggerMinutes, in: 0...(timeBlockDuration - (triggerSeconds > 0 ? 1 : 0))) {
                        HStack {
                            Text("\(triggerMinutes) 分钟")
                            Spacer()
                        }
                    }
                    
                    Stepper(value: $triggerSeconds, in: (triggerMinutes == timeBlockDuration ? 0 : 0)...(triggerMinutes == timeBlockDuration ? 0 : 59)) {
                        HStack {
                            Text("\(triggerSeconds) 秒")
                            Spacer()
                        }
                    }
                }
                
                Text("提示：从时间块开始后的时间")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("提醒消息")
                    .font(.subheadline)
                
                TextField("输入提醒消息", text: $message)
                    .textFieldStyle(.roundedBorder)
            }
            
            Toggle("启用声音提醒", isOn: $soundEnabled)
            
            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("保存") {
                    // 计算总的触发秒数
                    let triggerTime = triggerMinutes * 60 + triggerSeconds
                    onSave(triggerTime, message, soundEnabled)
                }
            .keyboardShortcut(.defaultAction)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 300)
    }
}

// 今日工作目标时间组件
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
    var name: String
}

// 饼图切片
struct PieSlice: View {
    var startAngle: Angle
    var endAngle: Angle
    var color: Color
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = min(geo.size.width, geo.size.height) / 2
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// 饼图组件
struct PieChartView: View {
    var data: [PieSliceData]
    
    private var totalValue: Double {
        data.reduce(0) { $0 + $1.value }
    }
    
    private func angle(for value: Double) -> Angle {
        guard totalValue > 0 else { return .degrees(0) }
        let fraction = value / totalValue
        return .degrees(fraction * 360)
    }
    
    private func startAngle(at index: Int) -> Angle {
        if index == 0 { return .zero }
        let sumOfPreviousValues = data[0..<index].reduce(0) { $0 + $1.value }
        return angle(for: sumOfPreviousValues)
    }
    
    private func endAngle(at index: Int) -> Angle {
        startAngle(at: index) + angle(for: data[index].value)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<data.count, id: \.self) { index in
                    PieSlice(
                        startAngle: startAngle(at: index),
                        endAngle: endAngle(at: index),
                        color: data[index].color
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
                
                // 中心红点
                Circle()
                    .fill(Color.red)
                    .frame(width: max(geo.size.width * 0.1, 10), height: max(geo.size.height * 0.1, 10))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// 时间统计视图
struct TimeStatsView: View {
    @ObservedObject var timeBlockManager: TimeBlockManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 添加今日工作目标
                TodayWorkTargetView(timeBlockManager: timeBlockManager)
                
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
            
            if timeBlockManager.historicalStats.totalSeconds > 0 {
                PieChartView(data: prepareChartData())
                    .frame(height: 200)
                    .padding(.bottom, 10) // 饼图和总时间之间的间距
                
                // 总使用时间
                HStack {
                    Text("总使用时间:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(timeBlockManager.historicalStats.totalSeconds))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.bottom, 10) // 总时间和图例之间的间距
                
                // 图例
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(prepareChartData()) { sliceData in
                        HStack {
                            Circle()
                                .fill(sliceData.color)
                                .frame(width: 10, height: 10)
                            Text(sliceData.name)
                                .font(.caption)
                            Spacer()
                            Text("\(formatTime(Int(sliceData.value))) - \(calculatePercentageString(sliceValue: sliceData.value))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
        // 注意：现在 value 将直接是秒数，而不是百分比，百分比在图例中动态计算
        return timeBlockManager.timeBlocks.compactMap { block in
            guard let usageSeconds = timeBlockManager.historicalStats.timeBlockUsage[block.id], usageSeconds > 0 else { return nil }
            return PieSliceData(
                id: block.id,
                value: Double(usageSeconds),
                color: block.color.toColor(),
                name: block.name
            )
        }
    }
    
    private func calculatePercentageString(sliceValue: Double) -> String {
        let total = Double(timeBlockManager.historicalStats.totalSeconds)
        guard total > 0 else { return "0" }
        let percentage = (sliceValue / total) * 100
        return String(format: "%.1f", percentage)
    }
    
    // 格式化时间
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(seconds)秒"
        }
    }
}

// 主视图
struct TBPopoverView: View {
    @ObservedObject var timer = TBTimer()
    @ObservedObject var settings = AppSettings.shared
    @State private var editingTimeBlock: TimeBlock?
    @State private var showAddTimeBlockSheet = false
    @State private var newTimeBlock = TimeBlock.createDefault(type: .work)
    @State private var managingRemindersForBlock: TimeBlock?
    @State private var viewSelection: String = "timeblocks"  // 默认视图
    @State private var settingsSelection: String = "general" // 默认设置页面

    var body: some View {
        VStack(spacing: 0) {
            // 当前时间块信息
            if let currentBlockIndex = timer.timeBlockManager.currentBlockIndex,
               let currentBlock = timer.timeBlockManager.timeBlocks[safe: currentBlockIndex] {
                // ...existing code...
            }
            
            // 视图选择器
            Picker("视图", selection: $viewSelection) {
                Text("时间块").tag("timeblocks")
                Text("时间统计").tag("stats")
                Text("设置").tag("settings")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)
            
            Divider()
                .padding(.top, 10)
            
            // 主内容区域
            if viewSelection == "timeblocks" {
                // 时间块列表
                ScrollView {
                    // 添加今日工作目标时间组件
                    TodayWorkTargetView(timeBlockManager: timer.timeBlockManager)
                    
                    // 添加刷新操作按钮
                    HStack {
                        Button(action: {
                            // 执行刷新操作
                            timer.timeBlockManager.refreshAllTimeBlocks()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("一键重置时间")
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    VStack(spacing: 8) {
                        ForEach(timer.timeBlockManager.timeBlocks.indices, id: \.self) { index in
                            TimeBlockRow(
                                timeBlock: timer.timeBlockManager.timeBlocks[index],
                                currentState: timer.timeBlockManager.currentState,
                                remainingSeconds: timer.timeBlockManager.getRemainingSeconds(for: timer.timeBlockManager.timeBlocks[index].id),
                                onTap: {
                                    // 获取当前块的索引
                                    let blockIndex = timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == timer.timeBlockManager.timeBlocks[index].id })
                                    let isCurrentBlock = timer.timeBlockManager.currentBlockIndex == blockIndex
                                    
                                    // 根据当前状态执行不同操作
                                    if timer.timeBlockManager.currentState == .idle {
                                        // 如果空闲状态，启动时间块
                                        if let index = blockIndex {
                                            timer.startTimeBlock(index: index)
                                        }
                                    } 
                                    else if isCurrentBlock {
                                        // 如果是当前活动的时间块
                                        if timer.timeBlockManager.currentState == .active {
                                            // 正在运行，点击暂停
                                            timer.pauseCurrentTimeBlock()
                                        } else if timer.timeBlockManager.currentState == .paused {
                                            // 已暂停，点击继续
                                            timer.resumeCurrentTimeBlock()
                                        }
                                    }
                                    else {
                                        // 点击了不同于当前活动的时间块，切换到该时间块
                                        // 先停止当前的，再启动新的
                                        timer.stopCurrentTimeBlock()
                                        if let index = blockIndex {
                                            timer.startTimeBlock(index: index)
                                        }
                                    }
                                },
                                onEdit: {
                                    editingTimeBlock = timer.timeBlockManager.timeBlocks[index]
                                },
                                onDelete: {
                                    timer.timeBlockManager.deleteTimeBlock(id: timer.timeBlockManager.timeBlocks[index].id)
                                },
                                onManageReminders: {
                                    managingRemindersForBlock = timer.timeBlockManager.timeBlocks[index]
                                },
                                onPauseResume: {
                                    // 这个回调现在不再使用，但为兼容性暂时保留
                                    // 原有逻辑已移到onTap处理
                                }
                            )
                            // 恢复右键菜单功能
                            .contextMenu {
                                Button(action: {
                                    editingTimeBlock = timer.timeBlockManager.timeBlocks[index]
                                }) {
                                    Label("编辑", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive, action: {
                                    timer.timeBlockManager.deleteTimeBlock(id: timer.timeBlockManager.timeBlocks[index].id)
                                }) {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button(action: {
                                    managingRemindersForBlock = timer.timeBlockManager.timeBlocks[index]
                                }) {
                                    Label("管理提醒", systemImage: "bell")
                                }
                            }
                        }
                        .onMove { from, to in
                            timer.timeBlockManager.moveTimeBlock(from: from, to: to)
                        }
                    }
                    .padding()
                    
                    Button(action: {
                        // 创建新的默认时间块
                        newTimeBlock = TimeBlock.createDefault(type: .work)
                        showAddTimeBlockSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加时间块")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                }
            } else if viewSelection == "stats" {
                // 时间统计视图
                TimeStatsView(timeBlockManager: timer.timeBlockManager)
            } else if viewSelection == "settings" {
                // 设置视图
                VStack(spacing: 0) {
                    // 设置选项卡
                    Picker("设置选项", selection: $settingsSelection) {
                        Text("常规").tag("general")
                        Text("声音").tag("sounds")
                    }
                    .pickerStyle(.segmented)
                    .padding([.horizontal, .top])
                    
                    Divider()
                        .padding(.top, 8)
                    
                    // 设置内容区域
                    ScrollView {
                        if settingsSelection == "general" {
                            SettingsView()
                                .environmentObject(timer)
                        } else if settingsSelection == "sounds" {
                            SoundsView()
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 240, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .sheet(isPresented: $showAddTimeBlockSheet) {
            TimeBlockEditView(
                timeBlock: $newTimeBlock,
                onSave: { hours, minutes in
                    // 计算新的总分钟数和总秒数
                    let totalMinutes = hours * 60 + minutes
                    let totalSeconds = hours * 3600 + minutes * 60
                    
                    // 创建新时间块并设置属性
                    var block = TimeBlock(
                        name: newTimeBlock.name,
                        duration: totalMinutes,
                        type: newTimeBlock.type,
                        color: newTimeBlock.color
                    )
                    block.savedRemainingSeconds = totalSeconds
                    
                    // 添加到时间块管理器
                    timer.timeBlockManager.timeBlocks.append(block)
                    
                    // 保存更改
                    timer.timeBlockManager.saveTimeBlocks()
                    
                    // 重要：手动触发对象变更通知，确保 UI 更新
                    timer.timeBlockManager.objectWillChange.send()
                    
                    showAddTimeBlockSheet = false
                },
                onCancel: {
                    showAddTimeBlockSheet = false
                }
            )
        }
        .sheet(item: $editingTimeBlock) { timeBlock in
            TimeBlockEditView(
                timeBlock: Binding(
                    get: { timeBlock },
                    set: { newValue in
                        // 更新editingTimeBlock以反映界面上的修改
                        editingTimeBlock = newValue
                    }
                ),
                onSave: { hours, minutes in
                    // 计算新的总分钟数和总秒数
                    let totalMinutes = hours * 60 + minutes
                    let totalSeconds = hours * 3600 + minutes * 60
                    
                    // 查找原始时间块
                    if let index = timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == timeBlock.id }) {
                        var updatedBlock = timer.timeBlockManager.timeBlocks[index]
                        
                        // 更新时间块的所有属性
                        updatedBlock.duration = totalMinutes
                        updatedBlock.savedRemainingSeconds = totalSeconds
                        updatedBlock.name = timeBlock.name
                        updatedBlock.type = timeBlock.type
                        updatedBlock.color = timeBlock.color
                        
                        // 将更新后的时间块放回数组中
                        timer.timeBlockManager.timeBlocks[index] = updatedBlock
                        
                        // 如果这是当前活动的时间块，更新 remainingSeconds
                        if timer.timeBlockManager.currentBlockIndex == index {
                            timer.timeBlockManager.remainingSeconds = totalSeconds
                            timer.updateTimeLeft()
                        }
                        
                        // 保存更改
                        timer.timeBlockManager.saveTimeBlocks()
                        
                        // 手动触发 UI 更新
                        timer.timeBlockManager.objectWillChange.send()
                        
                        // 打印调试信息
                        print("已更新时间块: ID=\(timeBlock.id), 名称=\(updatedBlock.name), 持续时间=\(totalMinutes)分钟, 剩余秒数=\(totalSeconds)")
                    }
                    
                    editingTimeBlock = nil
                },
                onCancel: {
                    editingTimeBlock = nil
                }
            )
        }
        .sheet(item: $managingRemindersForBlock) { timeBlock in
            TimeBlockRemindersView(
                timeBlock: timeBlock,
                onAddReminder: { triggerTime, message, soundEnabled in
                    // 添加提醒
                    if let index = timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == timeBlock.id }) {
                        timer.addReminderToTimeBlock(
                            timeBlockIndex: index,
                            triggerTime: triggerTime,
                            message: message,
                            soundEnabled: soundEnabled
                        )
                    }
                },
                onUpdateReminder: { reminderId, triggerTime, message, soundEnabled, enabled in
                    // 更新提醒
                    timer.timeBlockManager.updateReminder(
                        timeBlockId: timeBlock.id,
                        reminderId: reminderId,
                        triggerTime: triggerTime,
                        message: message,
                        soundEnabled: soundEnabled,
                        enabled: enabled
                    )
                },
                onDeleteReminder: { reminderId in
                    // 删除提醒
                    timer.timeBlockManager.deleteReminder(
                        timeBlockId: timeBlock.id,
                        reminderId: reminderId
                    )
                },
                onDismiss: {
                    managingRemindersForBlock = nil
                }
            )
        }
    }
}

// 扩展Array以安全访问元素
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#if DEBUG
    func debugSize(proxy: GeometryProxy) -> some View {
        print("Optimal popover size:", proxy.size)
        return Color.clear
    }
#endif
