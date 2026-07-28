import Foundation
import UserNotifications

/// 매일 반복 로컬 알림 (분 단위 지정)
enum ReminderManager {
    private static let id = "ilgigom.daily"

    static func enable(hour: Int, minute: Int) {
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            schedule(hour: hour, minute: minute)
        }
    }

    static func schedule(hour: Int, minute: Int) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "일기곰"
        content.body = "오늘 하루, 한 줄 남겨볼까요?"
        content.sound = .default

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        c.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
