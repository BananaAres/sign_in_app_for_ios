import SwiftUI

struct StatsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var planStore: PlanStore
    @State private var planStats: PlanStats?
    @State private var checkInStats: CheckInStats?
    @State private var isLoading = false
    @State private var showLoginSheet = false
    @State private var selectedRange: StatsRange = .month
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.statsBackgroundTop,
                        AppTheme.statsBackgroundBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        StatsHeader()
                            .padding(.top, 8)

                        StatsStreakCard(
                            streakDays: checkInStats?.streakDays ?? 0,
                            daysToGoal: 30
                        )

                        AchievementsCard(streakDays: checkInStats?.streakDays ?? 0)

                        StatsRangePicker(selectedRange: $selectedRange)

                        StatsMetricsRow(
                            checkInDays: checkInStats?.checkInDaysInRange ?? 0,
                            totalPlans: totalPlansInRange,
                            completionRate: Int((planStats?.completionRate ?? 0) * 100)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                if isLoading {
                    ProgressView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLoginSheet) {
                SignInView()
            }
            .task {
                await loadStats()
            }
            .onChange(of: selectedRange) { _ in
                Task {
                    await loadStats()
                }
            }
        }
    }
    
    private func loadStats() async {
        isLoading = true
        let range = statsRange()
        
        do {
            let plans = try await planStore.fetchPlans(from: range.start, to: range.end)
            let (plan, checkIn) = buildStats(from: plans, range: range)
            planStats = plan
            checkInStats = checkIn
        } catch {
            print("加载统计失败: \(error)")
        }
        isLoading = false
    }
    
    private var totalPlansInRange: Int {
        planStats?.totalPlans ?? 0
    }
    
    private func statsRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        var chinaCalendar = Calendar(identifier: .gregorian)
        chinaCalendar.firstWeekday = 2
        chinaCalendar.minimumDaysInFirstWeek = 4
        let endOfDay: (Date) -> Date = { date in
            calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: date)) ?? date
        }
        switch selectedRange {
        case .week:
            let start = chinaCalendar.date(
                from: chinaCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            ) ?? now
            let end = endOfDay(chinaCalendar.date(byAdding: .day, value: 6, to: start) ?? now)
            return (start, end)
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let end = calendar.date(byAdding: DateComponents(month: 1, day: 0, second: -1), to: start) ?? now
            return (start, end)
        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let end = calendar.date(byAdding: DateComponents(year: 1, second: -1), to: start) ?? now
            return (start, end)
        }
    }
    
    private func buildStats(from plans: [Plan], range: (start: Date, end: Date)) -> (PlanStats, CheckInStats) {
        let calendar = Calendar.current
        let dayBuckets = Dictionary(grouping: plans) { calendar.startOfDay(for: $0.startTime) }
        
        let completedPlans = plans.filter { $0.isCompleted }
        let totalPlans = plans.count
        let completedCount = completedPlans.count
        let completionRate = totalPlans == 0 ? 0 : Double(completedCount) / Double(totalPlans)
        
        func countCheckInDays(start: Date, end: Date) -> Int {
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            return dayBuckets
                .filter { day, items in
                    day >= startDay && day <= endDay && items.contains(where: { $0.isCompleted })
                }
                .count
        }

        let checkInDays = countCheckInDays(start: range.start, end: range.end)
        
        var chinaCalendar = Calendar(identifier: .gregorian)
        chinaCalendar.firstWeekday = 2
        chinaCalendar.minimumDaysInFirstWeek = 4
        let weekStart = chinaCalendar.date(
            from: chinaCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()
        let weekEnd = chinaCalendar.date(byAdding: .day, value: 6, to: weekStart) ?? Date()
        let thisWeekCheckIns = countCheckInDays(start: weekStart, end: weekEnd)
        
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? Date()
        let thisMonthCheckIns = countCheckInDays(start: monthStart, end: monthEnd)
        
        let streakDays = computeStreak(dayBuckets: dayBuckets, calendar: calendar)
        
        let weeklyData = (0..<7).compactMap { offset -> DailyStats? in
            guard let date = calendar.date(byAdding: .day, value: -6 + offset, to: calendar.startOfDay(for: Date())) else { return nil }
            let items = dayBuckets[calendar.startOfDay(for: date)] ?? []
            let completed = items.filter { $0.isCompleted }.count
            return DailyStats(
                id: ISO8601DateFormatter().string(from: date),
                date: date,
                completedCount: completed,
                totalCount: items.count
            )
        }
        
        let planStats = PlanStats(
            totalPlans: totalPlans,
            activePlans: totalPlans - completedCount,
            completedPlans: completedCount,
            completionRate: completionRate
        )
        
        let checkInStats = CheckInStats(
            totalCheckIns: completedCount,
            thisWeekCheckIns: thisWeekCheckIns,
            thisMonthCheckIns: thisMonthCheckIns,
            checkInDaysInRange: checkInDays,
            streakDays: streakDays,
            weeklyData: weeklyData
        )
        
        return (planStats, checkInStats)
    }
    
    private func computeStreak(dayBuckets: [Date: [Plan]], calendar: Calendar) -> Int {
        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())
        while true {
            let items = dayBuckets[currentDay] ?? []
            if items.contains(where: { $0.isCompleted }) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
                currentDay = previousDay
            } else {
                break
            }
        }
        return streak
    }
    
}

enum StatsRange: String, CaseIterable {
    case week = "本周"
    case month = "本月"
    case year = "全年"
}

struct StatsHeader: View {
    var body: some View {
        HStack {
            Text("打卡统计")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            ZStack(alignment: .topTrailing) {
                CatStickerButton(size: 50, imageName: CatPageIcon.stats) {
                    // TODO: 打开 AI 目标拆解
                }

                CatSparkleView()
                    .offset(x: -4, y: -6)
            }
        }
    }
}

struct StatsStreakCard: View {
    let streakDays: Int
    let daysToGoal: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.cardSecondary)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "flame.fill")
                            .foregroundColor(AppTheme.accentOrange)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("连续打卡")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 6) {
                        Text("\(streakDays)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("天")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(AppTheme.accentGold)
                    Text("坚持下去!")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accentOrange)
                }
            }

            ProgressView(value: Double(streakDays), total: Double(daysToGoal))
                .tint(AppTheme.accentOrange)

            Text("距离30天成就还差 \(max(daysToGoal - streakDays, 0)) 天")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

struct StatsRangePicker: View {
    @Binding var selectedRange: StatsRange

    var body: some View {
        HStack(spacing: 6) {
            ForEach(StatsRange.allCases, id: \.self) { range in
                Text(range.rawValue)
                    .font(.subheadline)
                    .foregroundColor(selectedRange == range ? .white : AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedRange == range ? AppTheme.accentOrange : Color.clear)
                    )
                    .onTapGesture {
                        selectedRange = range
                    }
            }
        }
        .padding(6)
        .background(AppTheme.card)
        .cornerRadius(16)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

struct StatsMetricsRow: View {
    let checkInDays: Int
    let totalPlans: Int
    let completionRate: Int

    var body: some View {
        HStack(spacing: 12) {
            StatsMetricCard(icon: "target", title: "打卡天数", value: "\(checkInDays)", color: AppTheme.accentOrange)
            StatsMetricCard(icon: "calendar", title: "计划数", value: "\(totalPlans)", color: AppTheme.accentGold)
            StatsMetricCard(icon: "chart.line.uptrend.xyaxis", title: "完成率", value: "\(completionRate)%", color: Color(red: 0.55, green: 0.46, blue: 0.32))
        }
    }
}

struct StatsMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(AppTheme.cardSecondary)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(color)
                )

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Text(title)
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card)
        .cornerRadius(16)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

struct AchievementsCard: View {
    let streakDays: Int
    
    var body: some View {
        let milestones = [
            (1, "初心者", "leaf"),
            (7, "坚持\n7天", "star.fill"),
            (30, "坚持\n30天", "trophy.fill"),
            (100, "坚持\n100天", "crown.fill")
        ]
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "rosette")
                    .foregroundColor(AppTheme.accentOrange)
                Text("成就徽章")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }

            HStack(spacing: 12) {
                ForEach(milestones, id: \.0) { milestone in
                    AchievementItem(
                        icon: milestone.2,
                        title: milestone.1,
                        isUnlocked: streakDays >= milestone.0
                    )
                }
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

struct AchievementItem: View {
    let icon: String
    let title: String
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(isUnlocked ? AppTheme.accentOrange.opacity(0.2) : AppTheme.cardSecondary)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(isUnlocked ? AppTheme.accentOrange : AppTheme.textSecondary)
                )

            Text(title)
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StatsView()
        .environmentObject(AuthManager.shared)
        .environmentObject(PlanStore())
}
