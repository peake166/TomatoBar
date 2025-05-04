import SwiftUI
import LaunchAtLogin

extension NSImage.Name {
    static let idle = Self("BarIconIdle")
    static let work = Self("BarIconWork")
    static let shortRest = Self("BarIconShortRest")
    static let longRest = Self("BarIconLongRest")
}

private let digitFont = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)

@main
struct TBApp: App {
    @NSApplicationDelegateAdaptor(TBStatusItem.self) var appDelegate

    init() {
        TBStatusItem.shared = appDelegate
        // 再次注释掉 LaunchAtLogin 功能
        // LaunchAtLogin.migrateIfNeeded()
        logger.append(event: TBLogEventAppStart())
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class TBStatusItem: NSObject, NSApplicationDelegate {
    private var popover = NSPopover()
    private var statusBarItem: NSStatusItem?
    private var statusBarMenu: NSMenu?
    
    static var shared: TBStatusItem!
    
    // 保存对主视图的引用，以便可以访问其数据
    private var mainView: TBPopoverView?

    func applicationDidFinishLaunching(_: Notification) {
        let view = TBPopoverView()
        mainView = view

        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: view)
        if let contentViewController = popover.contentViewController {
            popover.contentSize.height = contentViewController.view.intrinsicContentSize.height
            popover.contentSize.width = 240
        }

        statusBarItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        statusBarItem?.button?.imagePosition = .imageLeft
        setIcon(name: .idle)
        
        // 创建菜单
        setupMenu()
        
        // 设置左键点击和右键菜单
        statusBarItem?.button?.action = #selector(TBStatusItem.togglePopover(_:))
        statusBarItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // 注册应用终止通知
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
    }
    
    // 设置菜单
    private func setupMenu() {
        statusBarMenu = NSMenu()
        
        // 使用事件监听器区分左右键点击
        statusBarItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusBarItem?.button?.target = self
        statusBarItem?.button?.action = #selector(handleStatusItemClick(sender:))
    }
    
    // 处理状态栏图标点击事件
    @objc private func handleStatusItemClick(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover(sender)
        }
    }
    
    // 显示菜单
    private func showMenu() {
        guard let menu = statusBarMenu, let button = statusBarItem?.button else { return }
        
        // 清除旧菜单项
        menu.removeAllItems()
        
        // 添加时间块部分
        addTimeBlockMenuItems(to: menu)
        
        // 添加控制菜单项
        addControlMenuItems(to: menu)
        
        // 显示菜单
        menu.popUp(positioning: nil, at: NSPoint(x: button.frame.midX, y: button.frame.midY), in: button)
    }
    
    // 添加时间块菜单项
    private func addTimeBlockMenuItems(to menu: NSMenu) {
        guard let timeBlocks = mainView?.timer.timeBlockManager.timeBlocks, !timeBlocks.isEmpty else {
            let emptyItem = NSMenuItem(title: "没有可用的时间块", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            menu.addItem(NSMenuItem.separator())
            return
        }
        
        let currentIndex = mainView?.timer.timeBlockManager.currentBlockIndex
        let timeBlockTitle = NSMenuItem(title: "时间块", action: nil, keyEquivalent: "")
        timeBlockTitle.isEnabled = false
        menu.addItem(timeBlockTitle)
        
        for (index, block) in timeBlocks.enumerated() {
            let isActive = currentIndex == index
            let menuItem = NSMenuItem(
                title: "\(block.name) (\(block.duration)分钟)",
                action: #selector(timeBlockMenuItemClicked(_:)),
                keyEquivalent: ""
            )
            
            // 设置图标
            menuItem.image = NSImage(named: block.type.iconName())?.resize(to: NSSize(width: 16, height: 16))
            
            // 如果是活动块，添加勾选标记
            if isActive {
                menuItem.state = .on
            }
            
            // 设置标识符，用于识别点击的是哪个时间块
            menuItem.tag = index
            menu.addItem(menuItem)
        }
        
        menu.addItem(NSMenuItem.separator())
    }
    
    // 添加控制菜单项
    private func addControlMenuItems(to menu: NSMenu) {
        let currentState = mainView?.timer.timeBlockManager.currentState
        let hasActiveTimeBlock = mainView?.timer.timeBlockManager.currentBlockIndex != nil
        
        // 添加开始/暂停/继续/停止选项
        // 如果没有活动的时间块或处于空闲状态，显示开始选项
        if !hasActiveTimeBlock || currentState == .idle {
            let startItem = NSMenuItem(title: "开始", action: #selector(startMenuItemClicked), keyEquivalent: "")
            startItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
            menu.addItem(startItem)
        }
        // 如果有活动的时间块
        else if hasActiveTimeBlock {
            // 如果处于活动状态，显示暂停选项
            if currentState == .active {
                let pauseItem = NSMenuItem(title: "暂停", action: #selector(pauseMenuItemClicked), keyEquivalent: "")
                pauseItem.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil)
                menu.addItem(pauseItem)
            }
            // 如果处于暂停状态，显示继续选项
            else if currentState == .paused {
                let resumeItem = NSMenuItem(title: "继续", action: #selector(resumeMenuItemClicked), keyEquivalent: "")
                resumeItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
                menu.addItem(resumeItem)
            }
            
            // 跳过选项
            let skipItem = NSMenuItem(title: "跳过", action: #selector(skipMenuItemClicked), keyEquivalent: "")
            skipItem.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
            menu.addItem(skipItem)
            
            // 停止选项
            let stopItem = NSMenuItem(title: "停止", action: #selector(stopMenuItemClicked), keyEquivalent: "")
            stopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
            menu.addItem(stopItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 显示主窗口
        let showPopoverItem = NSMenuItem(title: "打开主窗口", action: #selector(showPopoverMenuItemClicked), keyEquivalent: "")
        showPopoverItem.image = NSImage(systemSymbolName: "window.maximize", accessibilityDescription: nil)
        menu.addItem(showPopoverItem)
        
        // 设置
        let settingsItem = NSMenuItem(title: "设置", action: #selector(settingsMenuItemClicked), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
    }
    
    // 时间块菜单项点击事件
    @objc private func timeBlockMenuItemClicked(_ sender: NSMenuItem) {
        mainView?.timer.startTimeBlock(index: sender.tag)
    }
    
    // 开始按钮点击事件
    @objc private func startMenuItemClicked() {
        guard let timeBlocks = mainView?.timer.timeBlockManager.timeBlocks, !timeBlocks.isEmpty else { return }
        
        // 默认启动第一个时间块
        mainView?.timer.startTimeBlock(index: 0)
    }
    
    // 暂停按钮点击事件
    @objc private func pauseMenuItemClicked() {
        mainView?.timer.pauseCurrentTimeBlock()
    }
    
    // 继续按钮点击事件
    @objc private func resumeMenuItemClicked() {
        mainView?.timer.resumeCurrentTimeBlock()
    }
    
    // 跳过按钮点击事件
    @objc private func skipMenuItemClicked() {
        mainView?.timer.skipCurrentTimeBlock()
    }
    
    // 停止按钮点击事件
    @objc private func stopMenuItemClicked() {
        mainView?.timer.stopCurrentTimeBlock()
    }
    
    // 显示主窗口按钮点击事件
    @objc private func showPopoverMenuItemClicked() {
        showPopover(nil)
    }
    
    // 设置按钮点击事件
    @objc private func settingsMenuItemClicked() {
        showPopover(nil)
    }
    
    // 应用终止时保存数据
    @objc func applicationWillTerminate(_ notification: Notification) {
        // 确保保存所有数据
        mainView?.timer.timeBlockManager.saveTimeBlocks()
        mainView?.timer.timeBlockManager.saveState()
    }
    
    // 应用激活时
    func applicationDidBecomeActive(_ notification: Notification) {
        // 刷新时间显示
        mainView?.timer.updateTimeLeft()
    }

    func setTitle(title: String?) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.9
        paragraphStyle.alignment = NSTextAlignment.center

        let attributedTitle = NSAttributedString(
            string: title != nil ? " \(title!)" : "",
            attributes: [
                NSAttributedString.Key.font: digitFont,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )
        statusBarItem?.button?.attributedTitle = attributedTitle
    }

    func setIcon(name: NSImage.Name) {
        statusBarItem?.button?.image = NSImage(named: name)
    }

    func showPopover(_: AnyObject?) {
        if let button = statusBarItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
}

// 扩展NSImage以调整大小
extension NSImage {
    func resize(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        
        let fromRect = NSRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        let toRect = NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        self.draw(in: toRect, from: fromRect, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        
        return newImage
    }
}
