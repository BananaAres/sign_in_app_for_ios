import SwiftUI

struct StatsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var planStore: PlanStore
    @State private var planStats: PlanStats?
    @State private var checkInStats: CheckInStats?
    @State private var completionTrend: [CompletionTrendPoint] = []
    @State private var trendEndIndex: Int = 0
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

                        CompletionTrendCard(
                            points: completionTrend,
                            trendEndIndex: trendEndIndex,
                            range: selectedRange
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
            let (plan, checkIn, trend, endIndex) = buildStats(from: plans, range: range, rangeKind: selectedRange)
            planStats = plan
            checkInStats = checkIn
            completionTrend = trend
            trendEndIndex = endIndex
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
    
    private func buildStats(from plans: [Plan], range: (start: Date, end: Date), rangeKind: StatsRange) -> (PlanStats, CheckInStats, [CompletionTrendPoint], Int) {
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
        
        let (trend, endIndex) = completionTrendPoints(dayBuckets: dayBuckets, range: range, rangeKind: rangeKind, calendar: calendar)
        return (planStats, checkInStats, trend, endIndex)
    }
    
    /// 看板展示全部周期；趋势判断用 endIndex 表示「到当前为止」的个数
    private func completionTrendPoints(dayBuckets: [Date: [Plan]], range: (start: Date, end: Date), rangeKind: StatsRange, calendar: Calendar) -> ([CompletionTrendPoint], Int) {
        let weekdayLabels = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let monthLabels = (1...12).map { "\($0)月" }
        let startDay = calendar.startOfDay(for: range.start)
        let todayStart = calendar.startOfDay(for: Date())
        
        switch rangeKind {
        case .week:
            let points = (0..<7).compactMap { offset -> CompletionTrendPoint? in
                guard let date = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
                let dayStart = calendar.startOfDay(for: date)
                let items = dayBuckets[dayStart] ?? []
                let total = items.count
                let completed = items.filter { $0.isCompleted }.count
                let rate = total > 0 ? Double(completed) / Double(total) : 0
                return CompletionTrendPoint(id: "w-\(offset)", label: weekdayLabels[offset], rate: rate)
            }
            let daysFromStart = calendar.dateComponents([.day], from: startDay, to: todayStart).day ?? 0
            let endIndex = min(7, max(0, daysFromStart) + 1)
            return (points, endIndex)
        case .month:
            let monthStart = calendar.startOfDay(for: range.start)
            let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            let weekCount = (dayCount + 6) / 7
            let currentDay = calendar.component(.day, from: Date())
            let currentWeekIndex = min((currentDay - 1) / 7, weekCount - 1)
            let endIndex = currentWeekIndex + 1
            let points = (0..<weekCount).compactMap { weekIndex -> CompletionTrendPoint? in
                let weekStartDay = weekIndex * 7 + 1
                let weekEndDay = min(weekIndex * 7 + 7, dayCount)
                guard let periodStart = calendar.date(byAdding: .day, value: weekStartDay - 1, to: monthStart),
                      let periodEnd = calendar.date(byAdding: .day, value: weekEndDay - 1, to: monthStart) else { return nil }
                let periodStartDay = calendar.startOfDay(for: periodStart)
                let periodEndDay = calendar.startOfDay(for: periodEnd)
                let periodPlans = dayBuckets.filter { day, _ in day >= periodStartDay && day <= periodEndDay }.flatMap { _, items in items }
                let total = periodPlans.count
                let completed = periodPlans.filter { $0.isCompleted }.count
                let rate = total > 0 ? Double(completed) / Double(total) : 0
                let label = "第\(weekIndex + 1)周"
                return CompletionTrendPoint(id: "m-\(weekIndex)", label: label, rate: rate)
            }
            return (points, endIndex)
        case .year:
            let currentMonthIndex = calendar.component(.month, from: Date()) - 1
            let endIndex = currentMonthIndex + 1
            let points = (0..<12).compactMap { monthOffset -> CompletionTrendPoint? in
                guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startDay),
                      let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { return nil }
                let monthPlans = dayBuckets.filter { day, _ in day >= monthStart && day <= monthEnd }.flatMap { _, items in items }
                let total = monthPlans.count
                let completed = monthPlans.filter { $0.isCompleted }.count
                let rate = total > 0 ? Double(completed) / Double(total) : 0
                return CompletionTrendPoint(id: "y-\(monthOffset)", label: monthLabels[monthOffset], rate: rate)
            }
            return (points, endIndex)
        }
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

struct CompletionTrendPoint: Identifiable {
    let id: String
    let label: String
    let rate: Double
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

// MARK: - 完成度看板（柱状 + 折线，柱上方显示完成度百分比）
struct CompletionTrendCard: View {
    let points: [CompletionTrendPoint]
    let trendEndIndex: Int
    let range: StatsRange
    
    /// 反馈文案仅根据「从开始到当前」的趋势判断
    private var feedbackText: String {
        let trendPoints = Array(points.prefix(trendEndIndex))
        guard !trendPoints.isEmpty else { return "暂无数据，快去添加计划吧～" }
        let rates = trendPoints.map(\.rate)
        let allHundred = rates.allSatisfy { $0 >= 0.99 }
        let allZero = rates.allSatisfy { $0 <= 0.01 }
        if allHundred { return "太棒了！保持全勤，继续加油～ 喵～" }
        if allZero { return "还没有完成记录哦，从今天开始打卡吧～ 喵～" }
        if trendPoints.count >= 2 {
            let mid = rates.count / 2
            let first = rates.prefix(mid).reduce(0, +) / Double(max(1, mid))
            let last = rates.suffix(rates.count - mid).reduce(0, +) / Double(max(1, rates.count - mid))
            if last > first + 0.05 { return "完成度在上升，很棒！继续保持～ 喵～" }
            if last < first - 0.05 { return "完成度有下滑，加把劲，明天会更好～ 喵～" }
        }
        return "稳扎稳打，明天继续加油～ 喵～"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(AppTheme.accentOrange)
                Text("完成度")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            if points.isEmpty {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                CompletionTrendChart(points: points)
                    .frame(height: 160)
                
                HStack(spacing: 4) {
                    ForEach(Array(points.enumerated()), id: \.element.id) { _, p in
                        Text(p.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Text(feedbackText)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

// MARK: - 柱状图（基准线在底部，柱上方显示百分比）
struct CompletionTrendChart: View {
    let points: [CompletionTrendPoint]
    
    var body: some View {
        GeometryReader { geo in
            let padding: CGFloat = 10
            let topLabelH: CGFloat = 18
            let chartH = max(0, geo.size.height - padding * 2 - topLabelH)
            let chartW = max(0, geo.size.width - padding * 2)
            let count = max(1, points.count)
            let stepX = chartW / CGFloat(count)
            let barW = stepX * 0.58
            
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach(Array(points.enumerated()), id: \.element.id) { _, p in
                        Text("\(Int(round(p.rate * 100)))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: stepX)
                    }
                }
                .frame(height: topLabelH)
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(points.enumerated()), id: \.element.id) { _, p in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.accentOrange.opacity(0.9), AppTheme.accentGold.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barW, height: max(2, chartH * CGFloat(p.rate)))
                        }
                        .frame(width: stepX, height: chartH)
                    }
                }
                .frame(height: chartH)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, padding)
            .padding(.vertical, padding)
        }
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
