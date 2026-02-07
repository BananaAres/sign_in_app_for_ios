import SwiftUI
import UIKit

// MARK: - 当天时间轴视图（0-24点）
struct DayTimelineView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var planStore: PlanStore
    @State private var selectedStartMinute: Int?
    @State private var selectedEndMinute: Int?
    @State private var showCreatePlanSheet = false
    @State private var isSelecting = false
    @State private var isSelectionValid = true
    @State private var selectionAnchorMinute: Int?
    @State private var currentDate: Date
    @State private var allPlans: [Plan]
    @State private var editingPlan: Plan?
    @State private var pendingDeletePlan: Plan?
    @State private var showDeleteDialog = false
    
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 60
    /// 框选时间步长：整点（60），点击某小时段内任意位置均从该小时 00 分开始
    private let minuteStep: Int = 60
    private let dayEndMinute: Int = 24 * 60
    private let calendar = Calendar.current
    private let chinaCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: currentDate)
    }

    private var isReadOnly: Bool {
        calendar.startOfDay(for: currentDate) < calendar.startOfDay(for: Date())
    }

    private var canToggleCompletion: Bool {
        calendar.isDate(currentDate, inSameDayAs: Date())
    }

    private var currentPlans: [Plan] {
        allPlans.filter { calendar.isDate($0.date, inSameDayAs: currentDate) }
    }

    init(date: Date, plans: [Plan]) {
        _currentDate = State(initialValue: date)
        _allPlans = State(initialValue: plans)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    TimelineHeader(title: dateString) {
                        dismiss()
                    }

                    DayStripView(
                        selectedDate: currentDate,
                        onSelect: { date in shiftDate(to: date) }
                    )

                    TimelineScrollView(
                        isSelecting: $isSelecting,
                        onLongPressBegan: { location in
                            guard !isReadOnly else { return }
                            // 检查登录状态
                            guard authManager.requireLogin() else { return }
                            if !isSelecting {
                                isSelecting = true
                                let anchor = minute(from: location, rounding: .down)
                                selectionAnchorMinute = min(anchor, dayEndMinute - minuteStep)
                                if let anchor = selectionAnchorMinute {
                                    updateSelection(start: anchor, end: min(anchor + minuteStep, dayEndMinute))
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        },
                        onLongPressChanged: { location in
                            guard !isReadOnly else { return }
                            guard let anchor = selectionAnchorMinute else { return }
                            let current = minute(from: location, rounding: .up)
                            updateSelection(start: anchor, end: current)
                        },
                        onLongPressEnded: { location in
                            guard !isReadOnly else { return }
                            guard let anchor = selectionAnchorMinute else {
                                isSelecting = false
                                return
                            }
                            let end = minute(from: location, rounding: .up)
                            updateSelection(start: anchor, end: end)
                            if isSelectionValid,
                               let start = selectedStartMinute,
                               let finish = selectedEndMinute,
                               start != finish {
                                showCreatePlanSheet = true
                            }
                            selectionAnchorMinute = nil
                            isSelecting = false
                        },
                        isTouchOnPlanBlock: { location in
                            // 用坐标计算判断触摸是否在任务块上
                            isTouchOnPlanBlock(location)
                        }
                    ) {
                        VStack(spacing: 0) {
                            ZStack(alignment: .topLeading) {
                                Color.clear
                                    .contentShape(Rectangle())

                                VStack(spacing: 0) {
                                    ForEach(hours, id: \.self) { hour in
                                        HourRow(hour: hour, height: hourHeight)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                guard !isReadOnly else { return }
                                                // 检查登录状态
                                                guard authManager.requireLogin() else { return }
                                                let start = hour * 60
                                                let end = min(dayEndMinute, start + 60)
                                                updateSelection(start: start, end: end)
                                                if isSelectionValid {
                                                    showCreatePlanSheet = true
                                                }
                                            }
                                    }
                                }

                                ForEach(currentPlans) { plan in
                                    PlanBlockView(
                                        plan: plan,
                                        date: currentDate,
                                        hourHeight: hourHeight,
                                        onDelete: { requestDelete(plan) },
                                        onEdit: { editingPlan = plan },
                                        onToggleComplete: { togglePlanCompletion(plan) },
                                        isSelecting: isSelecting,
                                        isReadOnly: isReadOnly,
                                        canToggleComplete: canToggleCompletion
                                    )
                                }

                                if let start = selectedStartMinute, let end = selectedEndMinute, start != end {
                                    SelectionBlock(
                                        startMinute: min(start, end),
                                        endMinute: max(start, end),
                                        minuteHeight: hourHeight / 60,
                                        isValid: isSelectionValid,
                                        onConfirm: {
                                            if isSelectionValid {
                                                showCreatePlanSheet = true
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.card)
                        .cornerRadius(18)
                        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreatePlanSheet) {
                if let startMinute = selectedStartMinute, let endMinute = selectedEndMinute {
                    PlanEditorView(
                        date: currentDate,
                        startMinute: min(startMinute, endMinute),
                        endMinute: max(startMinute, endMinute),
                        mode: .create(existingPlans: currentPlans, onCreate: { newPlans in
                            allPlans.append(contentsOf: newPlans)
                        })
                    )
                    .onDisappear {
                        selectedStartMinute = nil
                        selectedEndMinute = nil
                    }
                }
            }
            .sheet(item: $editingPlan) { plan in
                PlanEditorView(
                    date: plan.startTime,
                    mode: .edit(plan: plan, existingPlans: currentPlans, onUpdate: { updated in
                        if let index = allPlans.firstIndex(where: { $0.id == updated.id }) {
                            allPlans[index] = updated
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
            .onChange(of: showDeleteDialog) { isPresented in
                if !isPresented {
                    pendingDeletePlan = nil
                }
            }
        }
        .interactiveDismissDisabled(isSelecting)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) + 20 else { return }
                    if value.translation.width < -40 {
                        shiftDate(by: 1)
                    } else if value.translation.width > 40 {
                        shiftDate(by: -1)
                    }
                }
        )
    }


    private func updateSelection(start: Int, end: Int) {
        let clamped = clampSelection(start: start, end: end)
        selectedStartMinute = clamped.start
        selectedEndMinute = clamped.end
        isSelectionValid = !selectionConflicts(start: min(clamped.start, clamped.end), end: max(clamped.start, clamped.end))
    }

    private func selectionConflicts(start: Int, end: Int) -> Bool {
        for plan in currentPlans {
            let planStart = minutes(from: plan.startTime)
            let planEnd = dayEndMinuteValue(start: plan.startTime, end: plan.endTime, calendar: calendar, dayEndMinute: dayEndMinute)
            if start < planEnd && end > planStart {
                return true
            }
        }
        return false
    }

    private func clampSelection(start: Int, end: Int) -> (start: Int, end: Int) {
        if start == end { return (start, end) }
        let forward = end >= start
        let rangeStart = min(start, end)
        let rangeEnd = max(start, end)

        var boundary: Int? = nil

        for plan in currentPlans {
            let planStart = minutes(from: plan.startTime)
            let planEnd = dayEndMinuteValue(start: plan.startTime, end: plan.endTime, calendar: calendar, dayEndMinute: dayEndMinute)

            if forward {
                if start >= planStart && start < planEnd {
                    boundary = start
                    break
                }
                if planStart > start && planStart < end {
                    boundary = min(boundary ?? planStart, planStart)
                }
            } else {
                if start > planStart && start <= planEnd {
                    boundary = start
                    break
                }
                if planEnd < start && planEnd > end {
                    boundary = max(boundary ?? planEnd, planEnd)
                }
            }
        }

        if let boundary = boundary {
            return forward ? (start, boundary) : (boundary, end)
        }

        return (start, end)
    }

    private func minute(from location: CGPoint, rounding: FloatingPointRoundingRule) -> Int {
        let minuteHeight = hourHeight / 60
        let rawMinutes = location.y / minuteHeight
        let stepped = Int((rawMinutes / CGFloat(minuteStep)).rounded(rounding)) * minuteStep
        return max(0, min(dayEndMinute, stepped))
    }

    private func minutes(from date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour * 60 + minute
    }

    
    /// 判断触摸位置是否在任务块上（使用坐标计算，不依赖 UIKit hitTest）
    private func isTouchOnPlanBlock(_ location: CGPoint) -> Bool {
        // 布局 padding：垂直方向 12pt
        let verticalPadding: CGFloat = 12
        // 任务块左边距 62pt（时间列宽度）
        let planBlockLeft: CGFloat = 62
        
        // 如果触摸在左侧时间列，不是任务块
        if location.x < planBlockLeft {
            return false
        }
        
        // 调整 y 坐标（减去顶部 padding）
        let adjustedY = location.y - verticalPadding
        if adjustedY < 0 {
            return false
        }
        
        let minuteHeight = hourHeight / 60
        let touchMinute = Int(adjustedY / minuteHeight)
        
        // 检查是否在任何任务块的时间范围内
        for plan in currentPlans {
            let planStart = minutes(from: plan.startTime)
            let planEnd = dayEndMinuteValue(start: plan.startTime, end: plan.endTime, calendar: calendar, dayEndMinute: dayEndMinute)
            
            if touchMinute >= planStart && touchMinute < planEnd {
                return true
            }
        }
        
        return false
    }

    private func requestDelete(_ plan: Plan) {
        guard !isReadOnly else { return }
        if plan.repeatGroupId != nil {
            pendingDeletePlan = plan
            showDeleteDialog = true
        } else {
            deleteSinglePlan(plan)
        }
    }

    private func deleteSinglePlan(_ plan: Plan) {
        allPlans.removeAll { $0.id == plan.id }
        Task {
            try? await planStore.deletePlan(id: plan.id)
        }
    }

    private func deleteRepeatGroup(for plan: Plan) {
        guard let groupId = plan.repeatGroupId else { return }
        allPlans.removeAll { $0.repeatGroupId == groupId }
        Task {
            try? await planStore.deletePlansInRepeatGroup(
                groupId: groupId,
                from: Date.distantPast,
                excluding: nil
            )
        }
    }

    private func togglePlanCompletion(_ plan: Plan) {
        guard !isReadOnly, canToggleCompletion else { return }
        guard let index = allPlans.firstIndex(where: { $0.id == plan.id }) else { return }
        allPlans[index].isCompleted.toggle()
        allPlans[index].updatedAt = Date()
        let updatedPlan = allPlans[index]
        Task {
            try? await planStore.updatePlan(updatedPlan)
        }
    }

    private func shiftDate(by days: Int) {
        let next = calendar.date(byAdding: .day, value: days, to: currentDate) ?? currentDate
        shiftDate(to: next)
    }

    private func shiftDate(to date: Date) {
        currentDate = date
        selectedStartMinute = nil
        selectedEndMinute = nil
        selectionAnchorMinute = nil
        isSelecting = false
    }
}

private func dayEndMinuteValue(start: Date, end: Date, calendar: Calendar, dayEndMinute: Int) -> Int {
    let startDay = calendar.startOfDay(for: start)
    let endDay = calendar.startOfDay(for: end)
    let endMinutes = calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end)
    if endDay > startDay, endMinutes == 0 {
        return dayEndMinute
    }
    return endMinutes
}

struct TimelineHeader: View {
    let title: String
    let onDone: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Button(action: onDone) {
                Text("完成")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.accentOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardSecondary)
                    .cornerRadius(12)
            }
        }
    }
}

struct DayStripView: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current

    private var dates: [Date] {
        (-3...3).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: selectedDate)
        }
    }

    private func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayText(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(dates, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        onSelect(date)
                    } label: {
                        VStack(spacing: 6) {
                            Text(weekdayText(for: date))
                                .font(.caption2)
                                .foregroundColor(isSelected ? AppTheme.accentOrange : AppTheme.textSecondary)

                            Text(dayText(for: date))
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(isSelected ? AppTheme.accentOrange : Color.clear)
                                )
                                .scaleEffect(isSelected ? 1.12 : 1.0)
                                .shadow(color: AppTheme.accentOrange.opacity(isSelected ? 0.35 : 0), radius: 8, x: 0, y: 4)
                        }
                        .frame(width: 42)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selectedDate)
        }
    }
}

// MARK: - 小时行
struct HourRow: View {
    let hour: Int
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d:00", hour))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 50, alignment: .trailing)
                
                Rectangle()
                    .fill(AppTheme.textSecondary.opacity(0.2))
                    .frame(height: 1)
            }
            Spacer()
        }
        .frame(height: height)
    }
}

// MARK: - 计划块视图
struct PlanBlockView: View {
    let plan: Plan
    let date: Date
    let hourHeight: CGFloat
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onToggleComplete: () -> Void
    let isSelecting: Bool
    let isReadOnly: Bool
    let canToggleComplete: Bool
    
    private let dayEndMinute: Int = 24 * 60
    
    private var startMinuteValue: Int {
        Calendar.current.component(.hour, from: plan.startTime) * 60
            + Calendar.current.component(.minute, from: plan.startTime)
    }
    
    private var endMinuteValue: Int {
        dayEndMinuteValue(start: plan.startTime, end: plan.endTime, calendar: Calendar.current, dayEndMinute: dayEndMinute)
    }
    
    private var endTimeLabel: String {
        endMinuteValue == dayEndMinute ? "24:00" : plan.endTimeString
    }
    
    private var topOffset: CGFloat {
        let minuteHeight = hourHeight / 60
        return CGFloat(startMinuteValue) * minuteHeight
    }
    
    private var height: CGFloat {
        let start = CGFloat(startMinuteValue)
        let end = CGFloat(endMinuteValue)
        let minuteHeight = hourHeight / 60
        let proportional = (end - start) * minuteHeight
        return max(proportional, 2)
    }

    /// 高度达到此值时展示「计划名+时间」（约半小计划 30pt 即会展示）
    private let minHeightForTime: CGFloat = 26
    /// 高度达到此值时至少展示计划名（不足则截断为...）；低于此值什么都不展示
    private let minHeightForTitle: CGFloat = 18

    private var planCard: some View {
        Group {
            if height >= minHeightForTime {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(plan.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(plan.isCompleted ? 0.7 : 1))
                            .strikethrough(plan.isCompleted, color: .white.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 4)

                        if plan.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    Text("\(plan.startTimeString) - \(endTimeLabel)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(plan.isCompleted ? 0.6 : 0.8))
                }
                .padding(8)
            } else if height >= minHeightForTitle {
                HStack(spacing: 6) {
                    Text(plan.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(plan.isCompleted ? 0.7 : 1))
                        .strikethrough(plan.isCompleted, color: .white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    if plan.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            } else {
                Color.clear
                    .padding(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(plan.color.gradient.opacity(plan.isCompleted ? 0.55 : 1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(plan.isCompleted ? 0.25 : 0), lineWidth: 1)
        )
        .accessibilityIdentifier("planBlock")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: topOffset)
                .allowsHitTesting(false)

            planCard
                .frame(height: height)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isReadOnly, canToggleComplete, !isSelecting else { return }
                    onToggleComplete()
                }
                .contextMenu {
                    Button(action: onEdit) {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                }

            Spacer(minLength: 0)
                .allowsHitTesting(false)
        }
        .padding(.leading, 62)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(true)
    }
}

// MARK: - 选择块（拖拽选择时间段）
struct SelectionBlock: View {
    let startMinute: Int
    let endMinute: Int
    let minuteHeight: CGFloat
    let isValid: Bool
    let onConfirm: () -> Void
    
    private var topOffset: CGFloat {
        CGFloat(startMinute) * minuteHeight
    }
    
    private var height: CGFloat {
        CGFloat(endMinute - startMinute) * minuteHeight
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            if isValid {
                Button(action: onConfirm) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("创建计划")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.accentOrange, AppTheme.accentGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                }
            } else {
                Text("时间冲突")
                    .font(.subheadline)
                    .foregroundColor(Color.red.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(20)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(height, 60))
        .background(isValid ? AppTheme.accentOrange.opacity(0.12) : Color.red.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isValid ? AppTheme.accentOrange : Color.red.opacity(0.5), lineWidth: 2)
        )
        .padding(.leading, 62)
        .offset(y: topOffset)
    }
}

// MARK: - 计划编辑视图
enum PlanEditorMode {
    case create(existingPlans: [Plan], onCreate: ([Plan]) -> Void)
    case edit(plan: Plan, existingPlans: [Plan], onUpdate: (Plan) -> Void)
}

struct PlanEditorView: View {
    let date: Date
    let mode: PlanEditorMode
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var planStore: PlanStore
    
    @State private var title = ""
    @State private var note = ""
    @State private var selectedColor: PlanColor = .blue
    @State private var repeatMode: RepeatMode = .none
    @State private var notificationOptions: Set<PlanNotificationOption> = [.endTime]
    @State private var startMinuteValue: Int
    @State private var endMinuteValue: Int
    
    private let dayEndMinute: Int = 24 * 60
    /// 开始/结束时间分钟步长：5 分钟
    private let timeStep: Int = 5
    private let calendar = Calendar.current
    private let chinaCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()
    
    private let allowRepeat: Bool
    private let allowColor: Bool

    init(
        date: Date,
        startMinute: Int = 0,
        endMinute: Int = 0,
        allowRepeat: Bool = true,
        allowColor: Bool = true,
        mode: PlanEditorMode
    ) {
        self.date = date
        self.mode = mode
        self.allowRepeat = allowRepeat
        self.allowColor = allowColor
        let maxMinute = 24 * 60
        let maxStart = maxMinute - timeStep
        
        switch mode {
        case .create:
            let clampedStart = max(0, min(startMinute, maxStart))
            let clampedEnd = max(timeStep, min(endMinute, maxMinute))
            let safeEnd = max(clampedEnd, clampedStart + timeStep)
            let finalEnd = min(safeEnd, maxMinute)
            _startMinuteValue = State(initialValue: clampedStart)
            _endMinuteValue = State(initialValue: finalEnd)
        case .edit(let plan, _, _):
            let startValue = calendar.component(.hour, from: plan.startTime) * 60
                + calendar.component(.minute, from: plan.startTime)
            let endValue = dayEndMinuteValue(start: plan.startTime, end: plan.endTime, calendar: calendar, dayEndMinute: maxMinute)
            let clampedStart = max(0, min(startValue, maxStart))
            let clampedEnd = max(timeStep, min(endValue, maxMinute))
            _startMinuteValue = State(initialValue: clampedStart)
            _endMinuteValue = State(initialValue: max(clampedEnd, clampedStart + timeStep))
            _title = State(initialValue: plan.title)
            _note = State(initialValue: plan.note ?? "")
            _selectedColor = State(initialValue: plan.color)
            _repeatMode = State(initialValue: plan.repeatMode)
            _notificationOptions = State(initialValue: Set(plan.notificationOptions))
        }
        if !allowRepeat {
            _repeatMode = State(initialValue: .none)
        }
        if !allowColor {
            _selectedColor = State(initialValue: .orange)
        }
    }
    
    private var startTime: Date {
        timeDate(from: startMinuteValue, on: date)
    }
    
    private var endTime: Date {
        timeDate(from: endMinuteValue, on: date)
    }

    private var startTimeLabel: String {
        formatTime(minutes: startMinuteValue)
    }

    private var endTimeLabel: String {
        formatTime(minutes: endMinuteValue)
    }
    
    private var editorTitle: String {
        switch mode {
        case .create:
            return "新建计划"
        case .edit:
            return "编辑计划"
        }
    }
    
    private var existingPlans: [Plan] {
        switch mode {
        case .create(let plans, _):
            return plans
        case .edit(_, let plans, _):
            return plans
        }
    }
    
    private var editingPlanId: String? {
        switch mode {
        case .create:
            return nil
        case .edit(let plan, _, _):
            return plan.id
        }
    }
    
    private var isTimeRangeValid: Bool {
        startMinuteValue < endMinuteValue
    }
    
    private var timeRangeConflicts: Bool {
        let rangeStart = min(startMinuteValue, endMinuteValue)
        let rangeEnd = max(startMinuteValue, endMinuteValue)
        guard rangeStart != rangeEnd else { return false }
        for plan in existingPlans where plan.id != editingPlanId {
            let planStart = minutes(from: plan.startTime)
            let planEnd = dayEndMinuteValue(start: plan.startTime, end: plan.endTime, calendar: calendar, dayEndMinute: dayEndMinute)
            if rangeStart < planEnd && rangeEnd > planStart {
                return true
            }
        }
        return false
    }
    
    private var isTimeInvalid: Bool {
        !isTimeRangeValid || timeRangeConflicts
    }
    
    private var canSave: Bool {
        !title.isEmpty && !isTimeInvalid
    }
    
    private var startMinuteOptions: [Int] {
        Array(stride(from: 0, to: dayEndMinute, by: timeStep))
    }
    
    private var endMinuteOptions: [Int] {
        Array(stride(from: timeStep, through: dayEndMinute, by: timeStep))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Button("取消") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.textSecondary)

                        Spacer()

                        Text(editorTitle)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()

                        Button("保存") {
                            savePlan()
                        }
                        .foregroundColor(canSave ? AppTheme.accentOrange : AppTheme.textSecondary)
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    ScrollView {
                        VStack(spacing: 16) {
                            TimelineFormCard(title: "计划信息") {
                                VStack(spacing: 12) {
                                    TextField("计划标题", text: $title)
                                        .padding(12)
                                        .background(AppTheme.cardSecondary)
                                        .cornerRadius(12)

                                    TextField("备注（可选）", text: $note, axis: .vertical)
                                        .lineLimit(3...6)
                                        .padding(12)
                                        .background(AppTheme.cardSecondary)
                                        .cornerRadius(12)
                                }
                            }

                            TimelineFormCard(title: "时间") {
                                VStack(spacing: 12) {
                                    TimelineTimePickerRow(
                                        label: "开始时间",
                                        selection: $startMinuteValue,
                                        options: startMinuteOptions,
                                        isInvalid: isTimeInvalid,
                                        formatter: formatTime
                                    )
                                    TimelineTimePickerRow(
                                        label: "结束时间",
                                        selection: $endMinuteValue,
                                        options: endMinuteOptions,
                                        isInvalid: isTimeInvalid,
                                        formatter: formatTime
                                    )
                                    if isTimeInvalid {
                                        Text(timeRangeConflicts ? "时间冲突，请调整" : "结束时间需晚于开始时间")
                                            .font(.footnote)
                                            .foregroundColor(.red.opacity(0.75))
                                    }
                                }
                            }

                            if allowColor {
                                TimelineFormCard(title: "颜色") {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                                        ForEach(PlanColor.allCases, id: \.self) { color in
                                            ColorPickerButton(
                                                color: color,
                                                isSelected: selectedColor == color
                                            ) {
                                                selectedColor = color
                                            }
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }

                            if allowRepeat {
                                TimelineFormCard(title: "重复") {
                                    Picker("重复", selection: $repeatMode) {
                                        ForEach(
                                            [
                                                RepeatMode.none,
                                                .daily,
                                                .weekdays,
                                                .weekly,
                                                .monthly,
                                                .weeklyInCurrent,
                                                .monthlyInCurrent
                                            ],
                                            id: \.self
                                        ) { mode in
                                            Text(mode.displayName)
                                                .tag(mode)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 160)
                                }
                            }

                            TimelineFormCard(title: "通知") {
                                VStack(spacing: 10) {
                                    ForEach(PlanNotificationOption.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { option in
                                        NotificationOptionRow(
                                            title: option.displayName,
                                            isSelected: notificationOptions.contains(option)
                                        ) {
                                            toggle(option)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }
    
    private func savePlan() {
        switch mode {
        case .create(_, let onCreate):
            let plans = buildPlansForCreate()
            Task {
                do {
                    for plan in plans {
                        try await planStore.createPlan(plan)
                    }
                    await MainActor.run {
                        onCreate(plans)
                        dismiss()
                    }
                } catch {
                    print("创建计划失败: \(error)")
                }
            }
        case .edit(let plan, _, let onUpdate):
            Task {
                do {
                    let updated = try await updatePlanWithRepeat(plan)
                    await MainActor.run {
                        onUpdate(updated)
                        dismiss()
                    }
                } catch {
                    print("更新计划失败: \(error)")
                }
            }
        }
    }

    private func buildPlansForCreate() -> [Plan] {
        let durationMinutes = max(0, endMinuteValue - startMinuteValue)
        let startDay = calendar.startOfDay(for: date)
        let effectiveRepeatMode = allowRepeat ? repeatMode : .none
        let dates = repeatDates(from: startDay, mode: effectiveRepeatMode)
        let groupId = effectiveRepeatMode == .none ? nil : UUID().uuidString
        let options = notificationOptions.sorted { $0.sortOrder < $1.sortOrder }
        return dates.map { occurrence in
            let start = timeDate(from: startMinuteValue, on: occurrence)
            let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
            return Plan(
                id: UUID().uuidString,
                repeatGroupId: groupId,
                title: title,
                note: note.isEmpty ? nil : note,
                startTime: start,
                endTime: end,
                color: selectedColor,
                repeatMode: effectiveRepeatMode,
                notificationOptions: options,
                isCompleted: false,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }

    private func updatePlanWithRepeat(_ plan: Plan) async throws -> Plan {
        var updated = plan
        updated.title = title
        updated.note = note.isEmpty ? nil : note
        updated.startTime = startTime
        updated.endTime = endTime
        updated.color = selectedColor
        updated.repeatMode = repeatMode
        updated.notificationOptions = notificationOptions.sorted { $0.sortOrder < $1.sortOrder }
        updated.updatedAt = Date()

        let todayStart = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: updated.startTime)
        let regenStart = max(todayStart, startDay)
        let repeatModeChanged = repeatMode != plan.repeatMode

        if repeatMode == .none {
            if let groupId = updated.repeatGroupId {
                try await planStore.deletePlansInRepeatGroup(groupId: groupId, from: todayStart, excluding: updated.id)
            }
            updated.repeatGroupId = nil
            try await planStore.updatePlan(updated)
            return updated
        }

        if !repeatModeChanged, let groupId = updated.repeatGroupId {
            updated.repeatGroupId = groupId
            try await planStore.updatePlan(updated)
            return updated
        }

        let groupId = updated.repeatGroupId ?? UUID().uuidString
        updated.repeatGroupId = groupId
        try await planStore.deletePlansInRepeatGroup(groupId: groupId, from: todayStart, excluding: updated.id)
        try await planStore.updatePlan(updated)

        let durationMinutes = max(0, endMinuteValue - startMinuteValue)
        let dates: [Date]
        switch repeatMode {
        case .monthly:
            let endDay = repeatEndDate(for: startDay)
            dates = monthlyDates(from: startDay, to: endDay)
                .filter { $0 >= regenStart && calendar.startOfDay(for: $0) != startDay }
        case .daily, .weekdays, .weekly, .weeklyInCurrent, .monthlyInCurrent:
            dates = repeatDates(from: regenStart, mode: repeatMode)
                .filter { calendar.startOfDay(for: $0) != startDay }
        case .none:
            dates = []
        }
        for occurrence in dates {
            let start = timeDate(from: startMinuteValue, on: occurrence)
            let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
            let newPlan = Plan(
                id: UUID().uuidString,
                repeatGroupId: groupId,
                title: title,
                note: note.isEmpty ? nil : note,
                startTime: start,
                endTime: end,
                color: selectedColor,
                repeatMode: repeatMode,
                notificationOptions: notificationOptions.sorted { $0.sortOrder < $1.sortOrder },
                isCompleted: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await planStore.createPlan(newPlan)
        }

        return updated
    }

    private func repeatDates(from startDay: Date, mode: RepeatMode) -> [Date] {
        let endDay = repeatEndDate(for: startDay, mode: mode)
        switch mode {
        case .none:
            return [startDay]
        case .daily:
            return strideDates(from: startDay, to: endDay, stepDays: 1) { _ in true }
        case .weekdays:
            return strideDates(from: startDay, to: endDay, stepDays: 1) { date in
                let weekday = calendar.component(.weekday, from: date)
                return weekday >= 2 && weekday <= 6
            }
        case .weekly:
            return strideDates(from: startDay, to: endDay, stepDays: 7) { _ in true }
        case .monthly:
            return monthlyDates(from: startDay, to: endDay)
        case .weeklyInCurrent, .monthlyInCurrent:
            return strideDates(from: startDay, to: endDay, stepDays: 1) { _ in true }
        }
    }

    private func repeatEndDate(for startDay: Date, mode: RepeatMode = .daily) -> Date {
        switch mode {
        case .weeklyInCurrent:
            let startOfWeek = chinaCalendar.date(
                from: chinaCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDay)
            ) ?? startDay
            return chinaCalendar.date(byAdding: DateComponents(day: 6, hour: 23, minute: 59), to: startOfWeek) ?? startDay
        case .monthlyInCurrent:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDay)) ?? startDay
            return calendar.date(byAdding: DateComponents(month: 1, day: 0, second: -1), to: startOfMonth) ?? startDay
        default:
            let year = calendar.component(.year, from: startDay)
            return calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59)) ?? startDay
        }
    }

    private func strideDates(from start: Date, to end: Date, stepDays: Int, include: (Date) -> Bool) -> [Date] {
        var dates: [Date] = []
        var current = start
        while current <= end {
            if include(current) {
                dates.append(current)
            }
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: current) else { break }
            current = next
        }
        return dates
    }

    private func monthlyDates(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []
        let targetDay = calendar.component(.day, from: start)
        var offset = 0
        while true {
            guard let candidate = calendar.date(byAdding: .month, value: offset, to: start) else { break }
            if candidate > end {
                break
            }
            if calendar.component(.day, from: candidate) == targetDay {
                dates.append(calendar.startOfDay(for: candidate))
            }
            offset += 1
        }
        return dates
    }

    private func timeDate(from minutes: Int, on day: Date) -> Date {
        let clamped = max(0, min(dayEndMinute, minutes))
        let dayStart = calendar.startOfDay(for: day)
        if clamped == dayEndMinute {
            return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        }
        var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        components.hour = clamped / 60
        components.minute = clamped % 60
        return calendar.date(from: components) ?? date
    }
    
    private func minutes(from date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private func formatTime(minutes: Int) -> String {
        if minutes >= dayEndMinute {
            return "24:00"
        }
        let hour = minutes / 60
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private func toggle(_ option: PlanNotificationOption) {
        if notificationOptions.contains(option) {
            notificationOptions.remove(option)
        } else {
            notificationOptions.insert(option)
        }
    }
}

struct TimelineFormCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            content
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

struct TimelineInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.cardSecondary)
        .cornerRadius(12)
    }
}

struct NotificationOptionRow: View {
    let title: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.accentGreen : AppTheme.textSecondary)
                Text(title)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(AppTheme.cardSecondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct TimelineTimePickerRow: View {
    let label: String
    @Binding var selection: Int
    let options: [Int]
    let isInvalid: Bool
    let formatter: (Int) -> String
    
    @State private var showPicker = false
    @State private var tempHour: Int = 0
    @State private var tempMinute: Int = 0
    
    // 分解为小时和分钟
    private var hour: Int {
        min(selection / 60, 24)
    }
    
    private var minute: Int {
        selection % 60
    }
    
    // 是否是结束时间（允许24:00）
    private var allowsMidnight: Bool {
        options.contains(24 * 60)
    }
    
    private var displayText: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    /// 分钟按 5 分钟步长舍入，用于弹窗初始值
    private static func minuteRoundedToStep(_ m: Int) -> Int {
        min(55, ((m + 2) / 5) * 5)
    }

    var body: some View {
        Button(action: {
            tempHour = hour
            tempMinute = Self.minuteRoundedToStep(minute)
            showPicker = true
        }) {
            HStack {
                Text(label)
                    .foregroundColor(isInvalid ? .red.opacity(0.8) : AppTheme.textSecondary)
                
                Spacer()
                
                Text(displayText)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundColor(isInvalid ? .red.opacity(0.85) : AppTheme.textPrimary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(isInvalid ? Color.red.opacity(0.12) : AppTheme.cardSecondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            TimePickerSheet(
                label: label,
                hour: $tempHour,
                minute: $tempMinute,
                allowsMidnight: allowsMidnight,
                onConfirm: {
                    let clampedHour = min(tempHour, allowsMidnight ? 24 : 23)
                    let finalMinute = clampedHour == 24 ? 0 : tempMinute
                    selection = clampedHour * 60 + finalMinute
                    showPicker = false
                },
                onCancel: {
                    showPicker = false
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - 时间选择弹窗
private struct TimePickerSheet: View {
    let label: String
    @Binding var hour: Int
    @Binding var minute: Int
    let allowsMidnight: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Button("取消", action: onCancel)
                    .foregroundColor(AppTheme.textSecondary)
                
                Spacer()
                
                Text(label)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Button("确定", action: onConfirm)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accentOrange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // 滚轮选择器
            HStack(spacing: 0) {
                // 小时滚轮
                Picker("时", selection: $hour) {
                    ForEach(allowsMidnight ? Array(0...24) : Array(0...23), id: \.self) { h in
                        Text(String(format: "%02d", h))
                            .font(.system(size: 22, design: .monospaced))
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                
                Text(":")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                
                // 分钟滚轮（5 分钟步长：0, 5, 10, …, 55）
                Picker("分", selection: $minute) {
                    if hour == 24 {
                        Text("00")
                            .font(.system(size: 22, design: .monospaced))
                            .tag(0)
                    } else {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                            Text(String(format: "%02d", m))
                                .font(.system(size: 22, design: .monospaced))
                                .tag(m)
                        }
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 40)
            .onChange(of: hour) { newHour in
                if newHour == 24 {
                    minute = 0
                }
            }
            
            Spacer()
        }
        .background(AppTheme.background)
    }
}

struct ColorPickerButton: View {
    let color: PlanColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.gradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                )
        }
    }
}
