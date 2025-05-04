import UserNotifications

enum TBNotification {
    enum Category: String {
        case restStarted, restFinished
        case timeBlockStarted, timeBlockPaused, timeBlockFinished
        case timeBlockReminder
    }

    enum Action: String {
        case skipRest
        case pauseTimeBlock
        case resumeTimeBlock
        case skipTimeBlock
        case dismissReminder
    }
}

typealias TBNotificationHandler = (TBNotification.Action) -> Void

class TBNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private var center = UNUserNotificationCenter.current()
    private var handler: TBNotificationHandler?

    override init() {
        super.init()

        center.requestAuthorization(
            options: [.alert, .sound]
        ) { _, error in
            if error != nil {
                print("Error requesting notification authorization: \(error!)")
            }
        }

        center.delegate = self

        let actionSkipRest = UNNotificationAction(
            identifier: TBNotification.Action.skipRest.rawValue,
            title: NSLocalizedString("TBTimer.onRestStart.skip.title", comment: "Skip"),
            options: []
        )
        let actionPauseTimeBlock = UNNotificationAction(
            identifier: TBNotification.Action.pauseTimeBlock.rawValue,
            title: NSLocalizedString("TimeBlock.pause.title", comment: "Pause"),
            options: []
        )
        let actionResumeTimeBlock = UNNotificationAction(
            identifier: TBNotification.Action.resumeTimeBlock.rawValue,
            title: NSLocalizedString("TimeBlock.resume.title", comment: "Resume"),
            options: []
        )
        let actionSkipTimeBlock = UNNotificationAction(
            identifier: TBNotification.Action.skipTimeBlock.rawValue,
            title: NSLocalizedString("TimeBlock.skip.title", comment: "Skip"),
            options: []
        )
        let actionDismissReminder = UNNotificationAction(
            identifier: TBNotification.Action.dismissReminder.rawValue,
            title: NSLocalizedString("TimeBlock.reminder.dismiss", comment: "Dismiss"),
            options: []
        )
        
        let restStartedCategory = UNNotificationCategory(
            identifier: TBNotification.Category.restStarted.rawValue,
            actions: [actionSkipRest],
            intentIdentifiers: []
        )
        let restFinishedCategory = UNNotificationCategory(
            identifier: TBNotification.Category.restFinished.rawValue,
            actions: [],
            intentIdentifiers: []
        )
        let timeBlockStartedCategory = UNNotificationCategory(
            identifier: TBNotification.Category.timeBlockStarted.rawValue,
            actions: [actionPauseTimeBlock, actionSkipTimeBlock],
            intentIdentifiers: []
        )
        let timeBlockPausedCategory = UNNotificationCategory(
            identifier: TBNotification.Category.timeBlockPaused.rawValue,
            actions: [actionResumeTimeBlock, actionSkipTimeBlock],
            intentIdentifiers: []
        )
        let timeBlockFinishedCategory = UNNotificationCategory(
            identifier: TBNotification.Category.timeBlockFinished.rawValue,
            actions: [],
            intentIdentifiers: []
        )
        let timeBlockReminderCategory = UNNotificationCategory(
            identifier: TBNotification.Category.timeBlockReminder.rawValue,
            actions: [actionDismissReminder, actionPauseTimeBlock],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            restStartedCategory,
            restFinishedCategory,
            timeBlockStartedCategory,
            timeBlockPausedCategory,
            timeBlockFinishedCategory,
            timeBlockReminderCategory
        ])
    }

    func setActionHandler(handler: @escaping TBNotificationHandler) {
        self.handler = handler
    }

    func userNotificationCenter(_: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        if handler != nil {
            if let action = TBNotification.Action(rawValue: response.actionIdentifier) {
                handler!(action)
            }
        }
        
        completionHandler()
    }

    func send(title: String, body: String, category: TBNotification.Category) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.rawValue
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if error != nil {
                print("Error adding notification: \(error!)")
            }
        }
    }
    
    func sendWithSound(title: String, body: String, category: TBNotification.Category, sound: UNNotificationSound = .default) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.rawValue
        content.sound = sound
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if error != nil {
                print("Error adding notification with sound: \(error!)")
            }
        }
    }
    
    func scheduledNotification(title: String, body: String, category: TBNotification.Category, timeInterval: TimeInterval, sound: UNNotificationSound? = .default) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.rawValue
        
        if let sound = sound {
            content.sound = sound
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if error != nil {
                print("Error scheduling notification: \(error!)")
            }
        }
    }
    
    func sendTimeBlockStarted(name: String) {
        send(
            title: NSLocalizedString("TimeBlock.started.title", comment: "Time block started"),
            body: String(format: NSLocalizedString("TimeBlock.started.body", comment: "Time block %@ started"), name),
            category: .timeBlockStarted
        )
    }
    
    func sendTimeBlockPaused(name: String) {
        send(
            title: NSLocalizedString("TimeBlock.paused.title", comment: "Time block paused"),
            body: String(format: NSLocalizedString("TimeBlock.paused.body", comment: "Time block %@ paused"), name),
            category: .timeBlockPaused
        )
    }
    
    func sendTimeBlockFinished(name: String) {
        sendWithSound(
            title: NSLocalizedString("TimeBlock.finished.title", comment: "Time block finished"),
            body: String(format: NSLocalizedString("TimeBlock.finished.body", comment: "Time block %@ finished"), name),
            category: .timeBlockFinished
        )
    }
    
    func sendTimeBlockReminder(timeBlockName: String, reminderMessage: String) {
        sendWithSound(
            title: String(format: NSLocalizedString("TimeBlock.reminder.title", comment: "Reminder for %@"), timeBlockName),
            body: reminderMessage,
            category: .timeBlockReminder
        )
    }
    
    func scheduleTimeBlockReminder(timeBlockName: String, reminderMessage: String, triggerInSeconds: TimeInterval) {
        scheduledNotification(
            title: String(format: NSLocalizedString("TimeBlock.reminder.title", comment: "Reminder for %@"), timeBlockName),
            body: reminderMessage,
            category: .timeBlockReminder,
            timeInterval: triggerInSeconds
        )
    }
    
    func cancelAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    func cancelAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }
}
