import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var planStore: PlanStore
    @State private var plans: [Plan] = []
    @State private var isLoading = false
    @State private var showCreatePlanSheet = false
    @State private var createStartMinute = 0
    @State private var createEndMinute = 30

    private let calendar = Calendar.current
    private let columns = [
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        TodayHeader(dateText: todayText)
                        TodayStatsRow(
                            total: plans.count,
                            completed: plans.filter { $0.isCompleted }.count,
                            pending: plans.filter { !$0.isCompleted }.count
                        )

                        if plans.isEmpty, !isLoading {
                            EmptyTodayCard()
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(plans) { plan in
                                    TodayPlanCard(
                                        plan: plan,
                                        timeText: timeRange(for: plan),
                                        onToggleComplete: { toggleCompletion(plan) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.1)
                }

                VStack {
                    Spacer()
                    TodayAddButton {
                        prepareCreateDefaults()
                        showCreatePlanSheet = true
                    }
                }
                .padding(.bottom, 18)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreatePlanSheet) {
                PlanEditorView(
                    date: Date(),
                    startMinute: createStartMinute,
                    endMinute: createEndMinute,
                    allowRepeat: false,
                    allowColor: false,
                    mode: .create(existingPlans: plans, onCreate: { newPlans in
                        plans.append(contentsOf: newPlans)
                        plans.sort { $0.startTime < $1.startTime }
                    })
                )
            }
            .task {
                await loadPlans()
            }
        }
    }

    private var todayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }

    private func loadPlans() async {
        isLoading = true
        let today = Date()
        let start = calendar.startOfDay(for: today)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? today
        do {
            let fetched = try await planStore.fetchPlans(from: start, to: end)
            plans = fetched.sorted { $0.startTime < $1.startTime }
        } catch {
            plans = []
        }
        isLoading = false
    }

    private func prepareCreateDefaults() {
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let rounded = (minute / 30 + 1) * 30
        let startMinute = min(hour * 60 + rounded, 23 * 60 + 30)
        createStartMinute = startMinute
        createEndMinute = min(startMinute + 30, 24 * 60)
    }

    private func toggleCompletion(_ plan: Plan) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        var updated = plans[index]
        updated.isCompleted.toggle()
        updated.updatedAt = Date()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            plans[index] = updated
        }
        Task {
            try? await planStore.updatePlan(updated)
        }
    }

    private func timeRange(for plan: Plan) -> String {
        let start = plan.startTimeString
        let end: String = {
            let startDay = calendar.startOfDay(for: plan.startTime)
            let endDay = calendar.startOfDay(for: plan.endTime)
            if endDay > startDay,
               calendar.component(.hour, from: plan.endTime) == 0,
               calendar.component(.minute, from: plan.endTime) == 0 {
                return "24:00"
            }
            return plan.endTimeString
        }()
        return "\(start) - \(end)"
    }
}

private struct TodayHeader: View {
    let dateText: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(dateText)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
            CatStickerButton(style: .peek, size: 50) {
                // TODO: 今日计划小助手
            }
        }
        .padding(14)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

private struct TodayAddButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("新增今日计划")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [AppTheme.accentOrange, AppTheme.accentGold],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(22)
            .shadow(color: AppTheme.accentOrange.opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .padding(.horizontal, 20)
    }
}

private struct TodayStatsRow: View {
    let total: Int
    let completed: Int
    let pending: Int

    var body: some View {
        HStack(spacing: 12) {
            TodayStatChip(title: "计划数", value: total, color: AppTheme.accentGold)
            TodayStatChip(title: "完成数", value: completed, color: AppTheme.accentGreen)
            TodayStatChip(title: "未完成", value: pending, color: AppTheme.accentOrange)
        }
        .padding(12)
        .background(AppTheme.card)
        .cornerRadius(16)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

private struct TodayStatChip: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
            Text(title)
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.cardSecondary)
        .cornerRadius(12)
    }
}

private struct EmptyTodayCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(AppTheme.accentGold)
            Text("今天还没有计划")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("长按日历或在计划页创建新计划")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

private struct TodayPlanCard: View {
    let plan: Plan
    let timeText: String
    let onToggleComplete: () -> Void

    var body: some View {
        Button(action: onToggleComplete) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(timeText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Image(systemName: plan.isCompleted ? "checkmark.seal.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(plan.isCompleted ? AppTheme.accentGreen : AppTheme.textSecondary)
                            .scaleEffect(plan.isCompleted ? 1.1 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: plan.isCompleted)
                    }

                    Divider()
                        .background(AppTheme.textSecondary.opacity(0.2))

                    Text(plan.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(plan.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)
                        .strikethrough(plan.isCompleted, color: AppTheme.textSecondary.opacity(0.6))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .center)

                    if let note = plan.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(note)
                            .font(.callout)
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.cardSecondary,
                                    AppTheme.card
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.textSecondary.opacity(0.08), lineWidth: 1)
                        )
                )
                .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
                .overlay(
                    PinView(isCompleted: plan.isCompleted)
                        .offset(x: 14, y: -10),
                    alignment: .topLeading
                )
            }
            .scaleEffect(plan.isCompleted ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: plan.isCompleted)
        }
        .buttonStyle(.plain)
    }
}

private struct PinView: View {
    let isCompleted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? AppTheme.accentGreen : AppTheme.accentOrange)
                .frame(width: 18, height: 18)
                .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 2)

            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 6, height: 6)
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(PlanStore())
}
