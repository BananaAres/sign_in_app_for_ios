import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var planStore: PlanStore
    @State private var plans: [Plan] = []
    @State private var isLoading = false
    @State private var showCreatePlanSheet = false
    @State private var editingPlan: Plan?
    @State private var pendingDeletePlan: Plan?
    @State private var showDeleteDialog = false

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
                                        onToggleComplete: { toggleCompletion(plan) },
                                        onEdit: { editingPlan = plan },
                                        onDelete: { requestDelete(plan) }
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
                        showCreatePlanSheet = true
                    }
                }
                .padding(.bottom, 18)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreatePlanSheet) {
                TodayCreatePlanSheet(
                    existingPlans: plans,
                    onCreate: { newPlans in
                        plans.append(contentsOf: newPlans)
                        plans.sort { $0.startTime < $1.startTime }
                    }
                )
            }
            .sheet(item: $editingPlan) { plan in
                PlanEditorView(
                    date: plan.startTime,
                    allowRepeat: true,
                    allowColor: false,
                    mode: .edit(plan: plan, existingPlans: plans, onUpdate: { updated in
                        if let index = plans.firstIndex(where: { $0.id == updated.id }) {
                            plans[index] = updated
                            plans.sort { $0.startTime < $1.startTime }
                        }
                    })
                )
            }
            .confirmationDialog(
                "删除计划",
                isPresented: $showDeleteDialog,
                titleVisibility: .visible,
                presenting: pendingDeletePlan
            ) { plan in
                Button("仅删除此计划", role: .destructive) {
                    deleteSinglePlan(plan)
                    pendingDeletePlan = nil
                }
                if plan.repeatGroupId != nil {
                    Button("删除全部重复计划", role: .destructive) {
                        deleteRepeatGroup(for: plan)
                        pendingDeletePlan = nil
                    }
                }
                Button("取消", role: .cancel) {
                    pendingDeletePlan = nil
                }
            } message: { _ in
                Text("这是一个重复计划，要删除哪部分？")
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

    private func requestDelete(_ plan: Plan) {
        if plan.repeatGroupId != nil {
            pendingDeletePlan = plan
            showDeleteDialog = true
        } else {
            deleteSinglePlan(plan)
        }
    }

    private func deleteSinglePlan(_ plan: Plan) {
        plans.removeAll { $0.id == plan.id }
        Task {
            try? await planStore.deletePlan(id: plan.id)
        }
    }

    private func deleteRepeatGroup(for plan: Plan) {
        guard let groupId = plan.repeatGroupId else { return }
        plans.removeAll { $0.repeatGroupId == groupId }
        Task {
            try? await planStore.deletePlansInRepeatGroup(
                groupId: groupId,
                from: Date.distantPast,
                excluding: nil
            )
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
            CatStickerButton(size: 50, imageName: CatPageIcon.today) {
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
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var accentColor: Color {
        plan.isCompleted ? AppTheme.accentGreen : Color(red: 0.6, green: 0.5, blue: 0.9)
    }

    var body: some View {
        Button(action: onToggleComplete) {
            HStack(spacing: 0) {
                // 左侧彩色竖条
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 5)
                    .padding(.vertical, 12)
                    .padding(.leading, 6)

                // 完成勾选圆圈
                Image(systemName: plan.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(plan.isCompleted ? AppTheme.accentGreen : AppTheme.textSecondary.opacity(0.4))
                    .padding(.leading, 14)
                    .scaleEffect(plan.isCompleted ? 1.05 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: plan.isCompleted)

                // 计划内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(plan.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)
                        .strikethrough(plan.isCompleted, color: AppTheme.textSecondary.opacity(0.6))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                        Text(timeText)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(.leading, 12)

                Spacer()

                // 右侧小圆点
                Circle()
                    .fill(accentColor.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.card)
                    .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accentColor.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(plan.isCompleted ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: plan.isCompleted)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - 今日创建计划 Sheet（延迟计算默认值，避免卡顿）
private struct TodayCreatePlanSheet: View {
    let existingPlans: [Plan]
    let onCreate: ([Plan]) -> Void
    
    private var defaultStartMinute: Int {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let rounded = (minute / 30 + 1) * 30
        return min(hour * 60 + rounded, 23 * 60 + 30)
    }
    
    private var defaultEndMinute: Int {
        min(defaultStartMinute + 30, 24 * 60)
    }
    
    var body: some View {
        PlanEditorView(
            date: Date(),
            startMinute: defaultStartMinute,
            endMinute: defaultEndMinute,
            allowRepeat: false,
            allowColor: false,
            mode: .create(existingPlans: existingPlans, onCreate: onCreate)
        )
    }
}

#Preview {
    TodayView()
        .environmentObject(PlanStore())
}
