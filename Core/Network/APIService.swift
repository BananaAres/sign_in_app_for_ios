import Foundation

// MARK: - API Service (Mock for now)
class APIService {
    static let shared = APIService()
    
    private init() {}
    
    // MARK: - Auth
    func sendVerificationCode(phone: String) async throws {
        // TODO: 调用后端接口
        try await Task.sleep(nanoseconds: 1_000_000_000) // 模拟网络延迟
    }
    
    func verifyCode(phone: String, code: String) async throws -> String {
        // TODO: 调用后端接口，返回 token
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "mock_token_\(UUID().uuidString)"
    }
    
    // MARK: - Plans
    func fetchPlans(from: Date? = nil, to: Date? = nil) async throws -> [Plan] {
        // TODO: 调用后端接口 GET /plans?from=&to=
        try await Task.sleep(nanoseconds: 500_000_000)
        var plans = MockData.plans
        
        // 如果提供了日期范围，进行筛选
        if let from = from, let to = to {
            plans = plans.filter { plan in
                plan.startTime >= from && plan.startTime <= to
            }
        }
        
        return plans
    }
    
    func createPlan(_ plan: Plan) async throws -> Plan {
        // TODO: 调用后端接口 POST /plans
        try await Task.sleep(nanoseconds: 500_000_000)
        return plan
    }
    
    func updatePlan(_ plan: Plan) async throws -> Plan {
        // TODO: 调用后端接口 PATCH /plans/{id}
        try await Task.sleep(nanoseconds: 500_000_000)
        return plan
    }
    
    func deletePlan(id: String) async throws {
        // TODO: 调用后端接口 DELETE /plans/{id}
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    // MARK: - CheckIns
    func fetchCheckIns(planId: String?, from: Date?, to: Date?) async throws -> [CheckIn] {
        // TODO: 调用后端接口 GET /checkins?planId=&from=&to=
        try await Task.sleep(nanoseconds: 500_000_000)
        return MockData.checkIns.filter { checkIn in
            if let planId = planId, checkIn.planId != planId { return false }
            return true
        }
    }
    
    func createCheckIn(_ checkIn: CheckIn) async throws -> CheckIn {
        // TODO: 调用后端接口 POST /checkins
        try await Task.sleep(nanoseconds: 500_000_000)
        return checkIn
    }
    
    // MARK: - Stats
    func fetchStats(from: Date, to: Date) async throws -> (PlanStats, CheckInStats) {
        // TODO: 调用后端接口 GET /stats/summary?from=&to=
        try await Task.sleep(nanoseconds: 500_000_000)
        return (MockData.planStats, MockData.checkInStats)
    }
    
    // MARK: - User
    func fetchCurrentUser() async throws -> User? {
        // TODO: 调用后端接口 GET /user/me
        try await Task.sleep(nanoseconds: 500_000_000)
        return MockData.currentUser
    }
}

// MARK: - Mock Data
enum MockData {
    static let currentUser: User? = User(
        id: "user_001",
        appleUserId: "user_001",
        email: "test@example.com",
        fullName: "测试用户",
        nickname: "测试用户",
        avatar: nil,
        createdAt: Date()
    )
    
    static var plans: [Plan] {
        let calendar = Calendar.current
        let today = Date()
        var mockPlans: [Plan] = []
        
        // 今天的计划
        if let morningRunStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today),
           let morningRunEnd = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today) {
            mockPlans.append(Plan(
                id: "plan_001",
                repeatGroupId: nil,
                title: "晨跑",
                note: "保持健康",
                startTime: morningRunStart,
                endTime: morningRunEnd,
                color: .green,
                repeatMode: .weekly,
                isCompleted: false,
                createdAt: today,
                updatedAt: today
            ))
        }
        
        if let oralStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today),
           let oralEnd = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today) {
            mockPlans.append(Plan(
                id: "plan_002",
                repeatGroupId: nil,
                title: "口语练习",
                note: nil,
                startTime: oralStart,
                endTime: oralEnd,
                color: .red,
                repeatMode: .weekly,
                isCompleted: false,
                createdAt: today,
                updatedAt: today
            ))
        }
        
        if let reviewStart = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today),
           let reviewEnd = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: today) {
            mockPlans.append(Plan(
                id: "plan_003",
                repeatGroupId: nil,
                title: "复习",
                note: nil,
                startTime: reviewStart,
                endTime: reviewEnd,
                color: .purple,
                repeatMode: .none,
                isCompleted: false,
                createdAt: today,
                updatedAt: today
            ))
        }
        
        // 本周其他日期的计划（示例）
        for dayOffset in 1..<7 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                // 每周重复的计划
                if let runStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date),
                   let runEnd = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) {
                    mockPlans.append(Plan(
                        id: "plan_\(dayOffset)_001",
                        repeatGroupId: nil,
                        title: "晨跑",
                        note: nil,
                        startTime: runStart,
                        endTime: runEnd,
                        color: .green,
                        repeatMode: .weekly,
                        isCompleted: false,
                        createdAt: date,
                        updatedAt: date
                    ))
                }
            }
        }
        
        return mockPlans
    }
    
    static let checkIns: [CheckIn] = [
        CheckIn(
            id: "checkin_001",
            userId: "user_001",
            planId: "plan_003",
            occurredAt: Date().addingTimeInterval(-86400 * 2),
            value: 1.0,
            note: "今天读完了《设计模式》",
            createdAt: Date().addingTimeInterval(-86400 * 2)
        ),
        CheckIn(
            id: "checkin_002",
            userId: "user_001",
            planId: "plan_004",
            occurredAt: Date().addingTimeInterval(-86400 * 1),
            value: 1.0,
            note: "跑了5公里",
            createdAt: Date().addingTimeInterval(-86400 * 1)
        ),
        CheckIn(
            id: "checkin_003",
            userId: "user_001",
            planId: "plan_003",
            occurredAt: Date(),
            value: 1.0,
            note: nil,
            createdAt: Date()
        )
    ]
    
    static let planStats = PlanStats(
        totalPlans: 4,
        activePlans: 4,
        completedPlans: 0,
        completionRate: 0.75
    )
    
    static let checkInStats = CheckInStats(
        totalCheckIns: 15,
        thisWeekCheckIns: 5,
        thisMonthCheckIns: 12,
        checkInDaysInRange: 5,
        streakDays: 3,
        weeklyData: [
            DailyStats(id: "1", date: Date().addingTimeInterval(-86400 * 6), completedCount: 2, totalCount: 2),
            DailyStats(id: "2", date: Date().addingTimeInterval(-86400 * 5), completedCount: 1, totalCount: 2),
            DailyStats(id: "3", date: Date().addingTimeInterval(-86400 * 4), completedCount: 2, totalCount: 2),
            DailyStats(id: "4", date: Date().addingTimeInterval(-86400 * 3), completedCount: 0, totalCount: 2),
            DailyStats(id: "5", date: Date().addingTimeInterval(-86400 * 2), completedCount: 2, totalCount: 2),
            DailyStats(id: "6", date: Date().addingTimeInterval(-86400 * 1), completedCount: 1, totalCount: 2),
            DailyStats(id: "7", date: Date(), completedCount: 1, totalCount: 2)
        ]
    )
}
