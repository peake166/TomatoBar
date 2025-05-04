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
    var currentState: TimeBlockState  // 添加当前状态属性
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onManageReminders: () -> Void
    var onPauseResume: () -> Void    // 添加暂停/继续回调
    
    @State private var showContextMenu = false
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(timeBlock.color.toColor())
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(timeBlock.name)
                    .fontWeight(.medium)
                
                Text(formatDuration(timeBlock.duration))
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
            
            // 暂停/继续按钮 - 仅在该时间块处于活动状态时显示
            if isActive {
                Button(action: onPauseResume) {
                    Image(systemName: currentState == .active ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundColor(currentState == .active ? .orange : .green)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
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
    
    // 格式化时长显示
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)小时 \(remainingMinutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// 时间块编辑视图
private struct TimeBlockEditView: View {
    @Binding var timeBlock: TimeBlock
    var onSave: () -> Void
    var onCancel: () -> Void
    
    // 添加小时和分钟的状态变量
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    
    // 初始化函数
    init(timeBlock: Binding<TimeBlock>, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._timeBlock = timeBlock
        self.onSave = onSave
        self.onCancel = onCancel
        
        // 从timeBlock.duration转换为小时和分钟
        let totalMinutes = timeBlock.wrappedValue.duration
        let initialHours = totalMinutes / 60
        let initialMinutes = totalMinutes % 60
        
        self._hours = State(initialValue: initialHours)
        self._minutes = State(initialValue: initialMinutes)
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
                
                Button("保存", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(hours == 0 && minutes == 0) // 禁止保存零时长
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
        
        // 确保至少有1分钟的时长
        if totalMinutes == 0 && minutes == 0 && hours == 0 {
            minutes = 1
            timeBlock.duration = 1
        }
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
            
            // 时间块列表 - 修改为支持侧滑删除功能
            List {
                ForEach(timer.timeBlockManager.timeBlocks) { block in
                    TimeBlockRow(
                        timeBlock: block,
                        isActive: timer.timeBlockManager.currentBlockIndex == timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == block.id }),
                        currentState: timer.timeBlockManager.currentState,
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
                        },
                        onPauseResume: {
                            let isCurrentBlock = timer.timeBlockManager.currentBlockIndex == timer.timeBlockManager.timeBlocks.firstIndex(where: { $0.id == block.id })
                            if isCurrentBlock {
                                if timer.timeBlockManager.currentState == .active {
                                    timer.pauseCurrentTimeBlock()
                                } else if timer.timeBlockManager.currentState == .paused {
                                    timer.resumeCurrentTimeBlock()
                                }
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
                    .listRowBackground(Color.clear)
                    // 添加侧滑操作
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            blockToDelete = block.id
                            showDeleteAlert = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            editingBlock = block
                            isEditing = true
                            isAddingNew = false
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
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
                        // 更新时间块
                        timer.timeBlockManager.updateTimeBlock(
                            id: editingBlock.id,
                            name: editingBlock.name,
                            duration: editingBlock.duration,
                            type: editingBlock.type,
                            color: editingBlock.color
                        )
                    }
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
                                currentState: timer.timeBlockManager.currentState,
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
                                },
                                onPauseResume: {
                                    let isCurrentBlock = timer.timeBlockManager.currentBlockIndex == index
                                    if isCurrentBlock {
                                        if timer.timeBlockManager.currentState == .active {
                                            timer.pauseCurrentTimeBlock()
                                        } else if timer.timeBlockManager.currentState == .paused {
                                            timer.resumeCurrentTimeBlock()
                                        }
                                    }
                                }
                            )
                            // 添加侧滑手势删除功能
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
                    set: { newValue in
                        // 更新editingTimeBlock以反映界面上的修改
                        editingTimeBlock = newValue
                    }
                ),
                onSave: {
                    // 更新时间块
                    if let block = editingTimeBlock {
                        timer.timeBlockManager.updateTimeBlock(
                            id: block.id,
                            name: block.name,
                            duration: block.duration,
                            type: block.type,
                            color: block.color
                        )
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
