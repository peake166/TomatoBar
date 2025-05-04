<p align="center">
<img src="https://raw.githubusercontent.com/ivoronin/TomatoBar/main/TomatoBar/Assets.xcassets/AppIcon.appiconset/icon_128x128%402x.png" width="128" height="128"/>
<p>

<h1 align="center">TomatoBar (增强版)</h1>
<p align="center">
一款功能强大且高度可定制的 macOS 菜单栏番茄钟计时器。
</p>

## 概述

TomatoBar 是一款简洁高效的番茄工作法计时器，常驻在您的 macOS 菜单栏。它旨在帮助您通过番茄工作法（一种时间管理方法）来提高工作和学习效率，保持专注。此版本在原版基础上进行了大量功能增强和优化，使其更加灵活和用户友好。

## 主要功能

*   **高度可定制的时间块:**
    *   自由添加、编辑、删除和重新排序多个时间块（例如工作、短休息、长休息）。
    *   支持按小时和分钟设置时长，最长可达 24 小时。
    *   为每个时间块设置自定义名称和颜色标识。
*   **灵活的计时控制:**
    *   轻松开始、暂停、恢复或跳过当前时间块。
    *   点击时间块列表中的项目即可开始计时或切换。
    *   当鼠标悬停在时间块上时，会显示暂停/继续按钮（仅对活动块）。
*   **状态栏直观显示:**
    *   菜单栏图标会根据当前状态（工作、短休息、长休息、暂停、空闲）变化。
    *   可选在菜单栏直接显示剩余时间（格式：HH:MM:SS 或 MM:SS）。
    *   暂停状态下会有明确的"暂停"图标提示。
*   **便捷的操作方式:**
    *   全局快捷键（默认为用户可自定义）用于快速暂停/恢复当前计时器。
    *   鼠标悬停在时间块上会显示编辑和删除按钮。
    *   右键点击时间块可弹出上下文菜单，进行编辑、删除、管理提醒等操作。
    *   支持拖拽排序时间块。
*   **声音与提醒:**
    *   可在设置中独立开关计时开始、计时中（滴答声）、计时结束三种提示音。
    *   可分别调整三种提示音的音量。
    *   （未来可扩展）支持为每个时间块设置自定义提醒。
*   **应用设置:**
    *   **常规:** 配置全局快捷键、设置休息结束后是否自动停止、是否在菜单栏显示计时器。
    *   **声音:** 控制三种提示音的开关和音量。
    *   **退出:** 提供应用退出按钮。
*   **数据持久化与刷新:**
    *   应用会自动保存您的时间块列表和应用设置。
    *   时间块的剩余时间会在暂停或停止时保存，并在下次启动时恢复。
    *   提供"刷新时间"按钮，可将所有时间块重置为完整时长。
*   **启动优化:**
    *   应用启动时不再自动开始计时，而是等待用户手动选择。

## 使用指南

1.  **启动应用:** TomatoBar 会在菜单栏显示一个图标。
2.  **主界面:** 点击菜单栏图标会弹出主界面（Popover）。
3.  **时间块视图:**
    *   显示所有已添加的时间块列表。
    *   点击任意时间块开始计时。
    *   如果已有计时器在运行，点击其他时间块会停止当前计时并开始新的计时。
    *   鼠标悬停在时间块上会显示编辑和删除按钮。点击删除按钮会弹出确认框。
    *   右键点击时间块可进行编辑、删除等操作。
    *   拖拽时间块可以调整顺序。
    *   点击底部的"添加新时间块"按钮来创建新的计时块。
    *   点击顶部的"刷新时间"按钮将所有时间块恢复到完整时长。
    *   点击顶部的"显示/隐藏统计"按钮查看时间块的基本统计信息。
4.  **设置视图:**
    *   点击主界面顶部的"设置"选项卡进入。
    *   **常规:** 配置快捷键、菜单栏显示等。
    *   **声音:** 配置提示音开关和音量。
    *   点击"退出应用"按钮关闭 TomatoBar。
5.  **快捷键:** 使用您在设置中配置的全局快捷键来暂停或恢复当前正在进行的计时。

## 项目结构与逻辑

### 核心文件

*   **`TomatoBar/App.swift`:**
    *   应用入口 (`@main`)。
    *   管理状态栏项 (`TBStatusItem`) 的创建和行为（图标、标题、菜单、Popover 显示/隐藏）。
    *   处理应用生命周期事件（如启动、退出前保存数据）。
*   **`TomatoBar/View.swift`:**
    *   包含应用所有的 SwiftUI 视图定义。
    *   `TBPopoverView`: 主弹出窗口，包含视图切换逻辑（时间块/设置）。
    *   `TimeBlocksView`: 显示时间块列表、状态指示、刷新/统计按钮、添加按钮和底部状态栏。
    *   `TimeBlockRow`: 单个时间块的显示行，处理点击、悬停、上下文菜单等交互。
    *   `TimeBlockEditView`: 添加和编辑时间块的表单视图。
    *   `SettingsView`: 常规设置界面。
    *   `SoundsView`: 声音设置界面。
    *   其他辅助视图如 `StatusIndicatorView`, `TimeBlockStatsView`, `VolumeSlider` 等。
*   **`TomatoBar/State.swift`:**
    *   定义核心数据模型：`TimeBlock` (时间块结构), `TimeBlockReminder` (提醒结构), `AppSettings` (应用设置)。
    *   定义状态枚举：`TimeBlockType`, `TimeBlockColor`, `TimeBlockState` (计时器状态), `TimeBlockEvent` (状态转换事件)。
    *   `TimeBlockManager`: 核心状态管理器，负责：
        *   存储和管理 `timeBlocks` 列表。
        *   跟踪当前活动的时间块 (`currentBlockIndex`) 和剩余时间 (`remainingSeconds`)。
        *   管理计时器状态机 (`TimeBlockStateMachine`)。
        *   处理时间块的增删改查和排序。
        *   实现数据的加载 (`loadTimeBlocks`, `loadState`) 和保存 (`saveTimeBlocks`, `saveState`) 到 JSON 文件。
        *   提供 `refreshAllTimeBlocks` 方法。
    *   `AppSettings`: 使用 `@AppStorage` 将用户设置持久化到 UserDefaults。
*   **`TomatoBar/Timer.swift`:**
    *   `TBTimer` 类：计时器引擎和业务逻辑核心。
    *   持有 `TimeBlockManager` 实例来管理状态。
    *   管理系统计时器 (`DispatchSourceTimer`) 的创建、启动、停止。
    *   响应用户交互（如 `startTimeBlock`, `pauseCurrentTimeBlock`, `resumeCurrentTimeBlock`, `stopCurrentTimeBlock`, `skipCurrentTimeBlock`, `toggleCurrentTimeBlock`)。
    *   与 `TBPlayer` 交互播放声音。
    *   与 `TBNotificationCenter` 交互发送通知。
    *   更新状态栏图标和标题 (`TBStatusItem`)。
    *   处理快捷键事件。
    *   协调 `AppSettings` 和 `TimeBlockManager` 之间的数据同步。
*   **`TomatoBar/Player.swift`:**
    *   `TBPlayer` 类：封装 `AVAudioPlayer`，负责加载和播放应用的各种音效（开始、滴答、结束）。根据 `AppSettings` 控制声音是否启用及音量大小。
*   **`TomatoBar/Notifications.swift`:**
    *   `TBNotificationCenter` 类：封装 `UserNotifications` 框架，负责请求通知权限、配置通知类别和操作、发送不同类型的通知（如计时开始、暂停、结束、提醒）。

### 交互流程（示例：开始一个时间块）

1.  用户在 `TimeBlocksView` 中点击一个 `TimeBlockRow`。
2.  `TimeBlockRow` 的 `onTap` 回调被触发，调用 `TBPopoverView` 中传递的闭包。
3.  该闭包调用 `TBTimer` 实例的 `startTimeBlock(index:)` 方法。
4.  `TBTimer.startTimeBlock`:
    *   调用 `stopCurrentTimeBlock()` 停止任何正在运行的计时器（如果需要）。
    *   调用 `timeBlockManager.startTimeBlock(index:)`。
5.  `TimeBlockManager.startTimeBlock`:
    *   更新 `currentBlockIndex`。
    *   设置 `remainingSeconds`（如果 `savedRemainingSeconds` 存在则使用它，否则使用 `duration * 60`）。
    *   更新时间块的 `isActive` 状态。
    *   通过状态机 (`stateMachine`) 将状态转换为 `.active`。
    *   `@Published` 属性的变化会通知 `TBTimer` 和 SwiftUI 视图。
6.  `TBTimer.startTimeBlock` 继续执行：
    *   调用 `updateMenuBarIcon()` 更新状态栏图标和标题。
    *   调用 `player.playWindup()` 播放开始音效。
    *   如果时间块类型是工作，调用 `player.startTicking()`。
    *   调用 `notificationCenter.sendTimeBlockStarted()` 发送通知。
    *   调用 `startTimer()` 创建并启动系统 `DispatchSourceTimer`。
7.  `DispatchSourceTimer` 每秒触发 `onTimerTick()`。
8.  `onTimerTick`:
    *   在主线程调用 `timeBlockManager.updateTime()`。
9.  `TimeBlockManager.updateTime`:
    *   如果状态是 `.active`，将 `remainingSeconds` 减 1。
    *   检查是否需要触发提醒 (`checkReminders`)。
    *   如果 `remainingSeconds` 变为 0，调用 `finishCurrentTimeBlock()`。
10. `onTimerTick` 继续执行：
    *   调用 `updateTimeLeft()` 更新 `timeLeftString`，这会通过 `@Published` 更新 UI。
    *   如果状态变为 `.finished`，调用 `handleTimeBlockFinished()` 处理后续逻辑（如播放结束音效、根据设置自动开始下一个时间块等）。

### 数据持久化

*   **时间块列表:** 用户添加、编辑、删除或排序的时间块数据保存在 `~/Library/Containers/com.github.ivoronin.TomatoBar/Data/Documents/timeBlocks.json` 文件中。应用启动时加载，修改后自动保存。
*   **应用状态:** 当前活动时间块的索引、剩余秒数、已完成工作块数等状态信息保存在 `~/Library/Containers/com.github.ivoronin.TomatoBar/Data/Documents/timeBlockState.json` 文件中。应用退出或状态改变时保存。应用启动时只加载统计信息（如已完成块数），确保总是以空闲状态启动，但会从 `timeBlocks.json` 加载每个块保存的剩余时间。
*   **应用设置:** 如快捷键、声音开关/音量、菜单栏显示选项等，通过 `AppSettings` 类中的 `@AppStorage` 属性包装器直接保存在 macOS 的 `UserDefaults` 中。

## 安装

您可以从 <a href="https://github.com/ivoronin/TomatoBar/releases/latest/">GitHub Releases</a> 下载最新版本的 `.dmg` 文件进行安装。

或者，如果您使用 <a href="https://brew.sh/">Homebrew</a>，可以通过以下命令安装：
```bash
brew install --cask tomatobar
```
如果遇到应用无法启动的问题（通常是签名或检疫问题），可以尝试使用 `--no-quarantine` 标志：
```bash
brew install --cask --no-quarantine tomatobar
```

## 旧版本
Touch Bar 集成和对 Big Sur 之前 macOS 版本的支持在 TomatoBar 3.0 之前的版本中提供。

## 许可证
*   计时器声音从 buddhabeats 获得授权。
*   本项目基于 MIT 许可证。
