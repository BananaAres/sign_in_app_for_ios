import SwiftUI

struct StatsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var planStore: PlanStore
    @State private var planStats: PlanStats?
    @State private var checkInStats: CheckInStats?
    @State private var isLoading = false
    @State private var showLoginSheet = false
    @State private var selectedRange: StatsRange = .month
    @State private var heatmapValues: [Int] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.93, blue: 0.88),
                        Color(red: 0.96, green: 0.92, blue: 0.88)
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

                        StatsRangePicker(selectedRange: $selectedRange)

                        StatsMetricsRow(
                            checkInDays: checkInStats?.thisMonthCheckIns ?? 0,
                            totalDays: totalDaysInRange,
                            completionRate: Int((planStats?.completionRate ?? 0) * 100)
                        )

                        HeatmapCard(values: heatmapValues)

                        AchievementsCard(streakDays: checkInStats?.streakDays ?? 0)
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
            let (plan, checkIn, heatmap) = buildStats(from: plans, range: range)
            planStats = plan
            checkInStats = checkIn
            heatmapValues = heatmap
        } catch {
            print("加载统计失败: \(error)")
        }
        isLoading = false
    }
    
    private var totalDaysInRange: Int {
        let range = statsRange()
        let dayCount = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        return max(dayCount, 1)
    }
    
    private func statsRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        switch selectedRange {
        case .week:
            let end = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60 - 1)
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
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
    
    private func buildStats(from plans: [Plan], range: (start: Date, end: Date)) -> (PlanStats, CheckInStats, [Int]) {
        let calendar = Calendar.current
        let dayBuckets = Dictionary(grouping: plans) { calendar.startOfDay(for: $0.startTime) }
        let sortedDays = dayBuckets.keys.sorted()
        
        let completedPlans = plans.filter { $0.isCompleted }
        let totalPlans = plans.count
        let completedCount = completedPlans.count
        let completionRate = totalPlans == 0 ? 0 : Double(completedCount) / Double(totalPlans)
        
        let checkInDays = dayBuckets
            .filter { day, items in
                day >= calendar.startOfDay(for: range.start) && day <= calendar.startOfDay(for: range.end) &&
                items.contains(where: { $0.isCompleted })
            }
            .count
        
        let weekRangeStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        let weekPlans = plans.filter { $0.startTime >= weekRangeStart }
        let thisWeekCheckIns = weekPlans.filter { $0.isCompleted }.count
        
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let monthPlans = plans.filter { $0.startTime >= monthStart }
        let thisMonthCheckIns = monthPlans.filter { $0.isCompleted }.count
        
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
        
        let heatmapValues = buildHeatmap(dayBuckets: dayBuckets, calendar: calendar)
        
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
            streakDays: streakDays,
            weeklyData: weeklyData
        )
        
        _ = sortedDays
        return (planStats, checkInStats, heatmapValues)
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
    
    private func buildHeatmap(dayBuckets: [Date: [Plan]], calendar: Calendar) -> [Int] {
        let endDay = calendar.startOfDay(for: Date())
        let startDay = calendar.date(byAdding: .day, value: -83, to: endDay) ?? endDay
        return (0..<84).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let items = dayBuckets[calendar.startOfDay(for: day)] ?? []
            return items.filter { $0.isCompleted }.count
        }
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
                CatStickerButton(style: .peek, size: 50) {
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
    let totalDays: Int
    let completionRate: Int

    var body: some View {
        HStack(spacing: 12) {
            StatsMetricCard(icon: "target", title: "打卡天数", value: "\(checkInDays)", color: AppTheme.accentOrange)
            StatsMetricCard(icon: "calendar", title: "总天数", value: "\(totalDays)", color: AppTheme.accentGold)
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

struct HeatmapCard: View {
    let values: [Int]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 12)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("打卡热力图")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("近12周")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<max(values.count, 84), id: \.self) { index in
                    Circle()
                        .fill(heatColor(for: values[safe: index] ?? 0))
                        .frame(width: 12, height: 12)
                }
            }

            HStack(spacing: 8) {
                Text("少")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(heatColor(for: index))
                        .frame(width: 10, height: 10)
                }
                Text("多")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }

    private func heatColor(for value: Int) -> Color {
        switch value {
        case 0: return AppTheme.cardSecondary
        case 1: return AppTheme.accentOrange.opacity(0.25)
        case 2: return AppTheme.accentOrange.opacity(0.5)
        default: return AppTheme.accentOrange.opacity(0.8)
        }
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

#Preview {
    StatsView()
        .environmentObject(AuthManager.shared)
        .environmentObject(PlanStore())
}
