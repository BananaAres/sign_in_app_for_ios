import Foundation

// MARK: - Statistics Model
struct PlanStats: Codable {
    var totalPlans: Int
    var activePlans: Int
    var completedPlans: Int
    var completionRate: Double // 0.0 - 1.0
}

struct CheckInStats: Codable {
    var totalCheckIns: Int
    var thisWeekCheckIns: Int
    var thisMonthCheckIns: Int
    var streakDays: Int // 连续打卡天数
    var weeklyData: [DailyStats] // 最近7天的数据
}

struct DailyStats: Identifiable, Codable {
    let id: String
    var date: Date
    var completedCount: Int
    var totalCount: Int
}
