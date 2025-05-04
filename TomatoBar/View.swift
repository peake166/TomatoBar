import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
}

// 时间块行组件 - 显示单个时间块
private struct TimeBlockRow: View {
    var timeBlock: TimeBlock
    var isActive: Bool
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onManageReminders: () -> Void
    
    @State private var showContextMenu = false
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(timeBlock.color.toColor())
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(timeBlock.name)
                    .fontWeight(.medium)
                
                Text("\(timeBlock.duration) 分钟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 4)
            
            Spacer()
            
            // 类型标签
            Text(timeBlock.type.name())
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                )
            
            // 提醒标记（如果有提醒）
            if !timeBlock.reminders.isEmpty {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // 编辑按钮
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(action: onManageReminders) {
                Label("管理提醒", systemImage: "bell")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// 时间块编辑视图
private struct TimeBlockEditView: View {
    @Binding var timeBlock: TimeBlock
    var onSave: () -> Void
    var onCancel: () -> Void
    
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
                Text("时长 (分钟)")
                    .font(.subheadline)
                
                Stepper(value: $timeBlock.duration, in: 1...60) {
                    HStack {
                        Text("\(timeBlock.duration) 分钟")
                        Spacer()
                    }
                }
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
                
                Button("保存", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 300)
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
            
            // 时间块列表
            List {
                ForEach(timer.timeBlockManager.timeBlocks) { block in
                    TimeBlockRow(
                        timeBlock: block,
                        isActive: timer.timeBlockManager.currentBlockIndex == timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == block.id }),
                        onTap: {
                            // 如果当前无活动时间块，则开始这个时间块
                            if timer.timeBlockManager.currentState == .idle {
                                if let index = timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == block.id }) {
                                    timer.startTimeBlock(index: index)
                                }
                            }
                            // 如果当前正在运行这个时间块，则暂停
                            else if timer.timeBlockManager.currentBlockIndex == timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == block.id }) && timer.timeBlockManager.currentState == .active {
                                timer.pauseCurrentTimeBlock()
                            }
                            // 如果当前正在暂停这个时间块，则继续
                            else if timer.timeBlockManager.currentBlockIndex == timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == block.id }) && timer.timeBlockManager.currentState == .paused {
                                timer.resumeCurrentTimeBlock()
                            }
                            // 否则，如果有其他活动时间块，先停止然后开始这个
                            else if timer.timeBlockManager.currentState != .idle {
                                timer.stopCurrentTimeBlock()
                                if let index = timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == block.id }) {
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
            .frame(maxHeight: 200)
            
            // 底部操作区
            HStack {
                // 添加按钮
                Button {
                    // 创建一个新的默认时间块
                    editingBlock = TimeBlock(name: "", duration: 25, type: .work, color: .red, isActive: false)
                    isAddingNew = true
                    isEditing = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("添加")
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 统计按钮
                Button {
                    showStats.toggle()
                } label: {
                    HStack {
                        Image(systemName: "chart.bar")
                        Text("统计")
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // 统计视图
            if showStats {
                TimeBlockStatsView(timeBlocks: timer.timeBlockManager.timeBlocks)
                    .padding(.top, 4)
            }
        }
        .padding(4)
        .sheet(isPresented: $isEditing) {
            TimeBlockEditView(
                timeBlock: $editingBlock,
                onSave: {
                    if isAddingNew {
                        // 添加新时间块
                        timer.timeBlockManager.addTimeBlock(
                            name: editingBlock.name,
                            duration: editingBlock.duration,
                            type: editingBlock.type,
                            color: editingBlock.color
                        )
                    } else {
                        // 更新现有时间块
                        timer.timeBlockManager.updateTimeBlock(
                            id: editingBlock.id,
                            name: editingBlock.name,
                            duration: editingBlock.duration,
                            type: editingBlock.type,
                            color: editingBlock.color
                        )
                    }
                    isEditing = false
                },
                onCancel: {
                    isEditing = false
                }
            )
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                blockToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let id = blockToDelete {
                    // 如果当前正在运行这个时间块，先停止它
                    if timer.timeBlockManager.currentTimeBlock?.id == id {
                        timer.stopCurrentTimeBlock()
                    }
                    
                    // 删除时间块
                    timer.timeBlockManager.deleteTimeBlock(id: id)
                    blockToDelete = nil
                }
            }
        } message: {
            Text("你确定要删除这个时间块吗？此操作不可撤销。")
        }
    }
}

// 修改现有的IntervalsView以使用AppSettings
private struct IntervalsView: View {
    @ObservedObject var settings = AppSettings.shared
    private var minStr = NSLocalizedString("IntervalsView.min", comment: "min")

    var body: some View {
        VStack {
            Stepper(value: $settings.workIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalLength.label",
                                           comment: "Work interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, settings.workIntervalLength))
                }
            }
            Stepper(value: $settings.shortRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.shortRestIntervalLength.label",
                                           comment: "Short rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, settings.shortRestIntervalLength))
                }
            }
            Stepper(value: $settings.longRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.longRestIntervalLength.label",
                                           comment: "Long rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, settings.longRestIntervalLength))
                }
            }
            .help(NSLocalizedString("IntervalsView.longRestIntervalLength.help",
                                    comment: "Long rest interval hint"))
            Stepper(value: $settings.workIntervalsInSet, in: 1 ... 10) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalsInSet.label",
                                           comment: "Work intervals in a set label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(settings.workIntervalsInSet)")
                }
            }
            .help(NSLocalizedString("IntervalsView.workIntervalsInSet.help",
                                    comment: "Work intervals in set hint"))
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

// 修改现有的SettingsView以使用AppSettings
private struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @EnvironmentObject var timer: TBTimer
    // 再次注释掉 LaunchAtLogin 相关对象
    // @ObservedObject private var launchAtLogin = LaunchAtLogin.observable

    var body: some View {
        VStack {
            KeyboardShortcuts.Recorder(for: .startStopTimer) {
                Text(NSLocalizedString("SettingsView.shortcut.label",
                                       comment: "Shortcut label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $settings.stopAfterBreak) {
                Text(NSLocalizedString("SettingsView.stopAfterBreak.label",
                                       comment: "Stop after break label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Toggle(isOn: $settings.showTimerInMenuBar) {
                Text(NSLocalizedString("SettingsView.showTimerInMenuBar.label",
                                       comment: "Show timer in menu bar label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
                .onChange(of: settings.showTimerInMenuBar) {
                    timer.updateTimeLeft()
                }
            // 再次注释掉 LaunchAtLogin 相关 UI
            /*
            Toggle(isOn: $launchAtLogin.isEnabled) {
                Text(NSLocalizedString("SettingsView.launchAtLogin.label",
                                       comment: "Launch at login label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            */
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
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
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("SoundsView.isWindupEnabled.label",
                                   comment: "Windup label"))
            VolumeSlider(volume: $settings.windupVolume)
            Text(NSLocalizedString("SoundsView.isDingEnabled.label",
                                   comment: "Ding label"))
            VolumeSlider(volume: $settings.dingVolume)
            Text(NSLocalizedString("SoundsView.isTickingEnabled.label",
                                   comment: "Ticking label"))
            VolumeSlider(volume: $settings.tickingVolume)
        }.padding(4)
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
    case intervals, timeBlocks, settings, sounds
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

// 主视图
struct TBPopoverView: View {
    @ObservedObject var timer = TBTimer()
    @ObservedObject var settings = AppSettings.shared
    @State private var editingTimeBlock: TimeBlock?
    @State private var showAddTimeBlockSheet = false
    @State private var newTimeBlock = TimeBlock.createDefault(type: .work)
    @State private var managingRemindersForBlock: TimeBlock?
    @State private var viewSelection: String = "timeblocks"  // 默认视图

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
                    VStack(spacing: 8) {
                        ForEach(timer.timeBlockManager.timeBlocks.indices, id: \.self) { index in
                            TimeBlockRow(
                                timeBlock: timer.timeBlockManager.timeBlocks[index],
                                isActive: timer.timeBlockManager.currentBlockIndex == index,
                                onTap: {
                                    // 只有在空闲状态或点击的不是当前活动块时才启动
                                    if timer.timeBlockManager.currentState == .idle || timer.timeBlockManager.currentBlockIndex != index {
                                        timer.startTimeBlock(index: index)
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
                                }
                            )
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
            } else {
                // 设置视图
                // ... existing settings code ...
            }
        }
        .frame(minWidth: 240, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .sheet(isPresented: $showAddTimeBlockSheet) {
            TimeBlockEditView(
                timeBlock: $newTimeBlock,
                onSave: {
                    // 添加新的时间块
                    timer.timeBlockManager.addTimeBlock(
                        name: newTimeBlock.name,
                        duration: newTimeBlock.duration,
                        type: newTimeBlock.type,
                        color: newTimeBlock.color
                    )
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
                    set: { _ in }
                ),
                onSave: {
                    // 更新时间块
                    timer.timeBlockManager.updateTimeBlock(
                        id: timeBlock.id,
                        name: timeBlock.name,
                        duration: timeBlock.duration,
                        type: timeBlock.type,
                        color: timeBlock.color
                    )
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
