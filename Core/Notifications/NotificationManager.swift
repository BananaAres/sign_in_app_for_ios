import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    func cancelNotifications(for planId: String) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: planId))
    }

    func scheduleNotifications(for plan: Plan) async {
        let isAllowed = await requestAuthorizationIfNeeded()
        guard isAllowed else { return }
        guard !plan.notificationOptions.isEmpty else { return }

        for option in plan.notificationOptions {
            let triggerDate = triggerDate(for: plan, option: option)
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "计划提醒"
            content.body = bodyText(for: plan, option: option)
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier(for: plan.id, option: option),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func triggerDate(for plan: Plan, option: PlanNotificationOption) -> Date {
        switch option {
        case .start5:
            return Calendar.current.date(byAdding: .minute, value: -5, to: plan.startTime) ?? plan.startTime
        case .start10:
            return Calendar.current.date(byAdding: .minute, value: -10, to: plan.startTime) ?? plan.startTime
        case .endTime:
            return plan.endTime
        }
    }

    private func bodyText(for plan: Plan, option: PlanNotificationOption) -> String {
        switch option {
        case .start5:
            return "您的计划【\(plan.title)】将于5分钟后开始，不要忘记完成呦！喵~"
        case .start10:
            return "您的计划【\(plan.title)】将于10分钟后开始，不要忘记完成呦！喵~"
        case .endTime:
            return "您的计划【\(plan.title)】已经结束啦，如果完成了不要忘记来打卡！喵~"
        }
    }

    private func identifiers(for planId: String) -> [String] {
        PlanNotificationOption.allCases.map { identifier(for: planId, option: $0) }
    }

    private func identifier(for planId: String, option: PlanNotificationOption) -> String {
        "plan.\(planId).\(option.rawValue)"
    }
}
