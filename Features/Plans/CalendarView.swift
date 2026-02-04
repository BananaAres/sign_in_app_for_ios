import SwiftUI

// MARK: - 日历视图（首页）
// 用于 fullScreenCover(item:) 的日期包装器
struct SelectedDateItem: Identifiable {
    let id = UUID()
    let date: Date
}

struct CalendarView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var planStore: PlanStore
    let onShowCover: (() -> Void)?
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var plans: [Plan] = []
    @State private var isLoading = false
    @State private var monthPlanItems: [GoalItem] = []
    @State private var isMonthGoalsExpanded = false
    @State private var showMonthEditor = false
    @State private var showLoginSheet = false
    @State private var selectedDateItem: SelectedDateItem? = nil  // 用于 fullScreenCover
    @State private var viewMode: ViewMode = .calendar

    init(onShowCover: (() -> Void)? = nil) {
        self.onShowCover = onShowCover
    }
    
    enum ViewMode {
        case calendar
        case week
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: currentMonth)
    }

    private var monthPlanKey: String {
        PlanTextStore.monthKey(for: currentMonth)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        MonthlyHeader(
                            title: "月度计划",
                            onBack: {
                                onShowCover?()
                            }
                        )
                        .padding(.top, 8)

                        MonthlyGoalsCard(
                            completedCount: completedMonthGoals,
                            totalCount: max(monthPlanItems.count, 5),
                            items: $monthPlanItems,
                            isExpanded: $isMonthGoalsExpanded,
                            onToggle: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    isMonthGoalsExpanded.toggle()
                                }
                            },
                            onEdit: { showMonthEditor = true }
                        )

                        MonthViewTabs(selectedMode: $viewMode)

                        if viewMode == .calendar {
                            MonthCalendarCard(
                                monthDate: currentMonth,
                                selectedDate: $selectedDate,
                                plans: plans,
                                onPrevious: {
                                    withAnimation {
                                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                                    }
                                },
                                onNext: {
                                    withAnimation {
                                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                                    }
                                },
                                onDateSelected: {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        selectedDateItem = SelectedDateItem(date: selectedDate)
                                    }
                                }
                            )
                        } else {
                            WeekGridView(
                                selectedDate: $selectedDate,
                                plans: plans
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbar {
                if let onShowCover = onShowCover {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            onShowCover()
                        } label: {
                            Label("封面", systemImage: "book.closed")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if authManager.isAuthenticated {
                            // TODO: 导航到创建计划
                        } else {
                            showLoginSheet = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLoginSheet) {
                SignInView()
            }
            .fullScreenCover(item: $selectedDateItem, onDismiss: {
                Task {
                    await loadPlans()
                }
            }, content: { item in
                DayTimelineView(
                    date: item.date,
                    plans: plans
                )
            })
            .sheet(isPresented: $showMonthEditor) {
                MonthPlanEditorSheet(items: $monthPlanItems)
                    .presentationDetents([.fraction(0.7)])
            }
            .task {
                loadMonthPlan()
                await loadPlans()
            }
            .onChange(of: currentMonth) { _ in
                loadMonthPlan()
                Task {
                    await loadPlans()
                }
            }
            .onChange(of: monthPlanItems) { newValue in
                saveMonthPlan(newValue)
            }
            .refreshable {
                await loadPlans()
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 60, let onShowCover = onShowCover {
                            onShowCover()
                            return
                        }
                    }
            )
        }
    }
    
    private func loadPlans() async {
        isLoading = true
        do {
            // 加载当前月份的计划
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            plans = try await planStore.fetchPlans(from: startOfMonth, to: endOfMonth)
        } catch {
            print("加载计划失败: \(error)")
        }
        isLoading = false
    }

    private func loadMonthPlan() {
        let loaded = PlanTextStore.loadGoals(key: monthPlanKey)
        monthPlanItems = Array(loaded.prefix(8))
    }

    private func saveMonthPlan(_ items: [GoalItem]) {
        PlanTextStore.saveGoals(items, key: monthPlanKey)
    }

    private var completedMonthGoals: Int {
        monthPlanItems.filter { $0.isCompleted }.count
    }
}

struct MonthlyHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.cardSecondary)
                    .clipShape(Circle())
            }

            Spacer()

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            ZStack(alignment: .topTrailing) {
                CatStickerButton(style: .head, size: 48) {
                    // TODO: 打开 AI 目标拆解
                }

                CatSparkleView()
                    .offset(x: -4, y: -6)
            }
        }
    }
}

struct MonthlyGoalsCard: View {
    let completedCount: Int
    let totalCount: Int
    @Binding var items: [GoalItem]
    @Binding var isExpanded: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppTheme.accentOrange)
                            .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("本月目标")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)

                            Text("\(min(completedCount, totalCount))/\(totalCount) 已完成")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("编辑")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppTheme.accentOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardSecondary)
                    .cornerRadius(12)
                }

                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline)
                        .foregroundColor(AppTheme.accentOrange)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.cardSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                if items.isEmpty {
                    Button(action: onEdit) {
                        Text("点击添加本月目标")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 10) {
                        ForEach(items.indices, id: \.self) { index in
                            Button {
                                items[index].isCompleted.toggle()
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(items[index].isCompleted ? AppTheme.accentOrange : Color.gray.opacity(0.6))
                                        .frame(width: 9, height: 9)

                                    Text(items[index].text)
                                        .font(.subheadline)
                                        .foregroundColor(items[index].isCompleted ? AppTheme.textSecondary.opacity(0.6) : AppTheme.textSecondary)
                                        .strikethrough(items[index].isCompleted, color: AppTheme.textSecondary.opacity(0.6))
                                        .lineLimit(1)

                                    Spacer()

                                    if items[index].isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.footnote)
                                            .foregroundColor(AppTheme.accentOrange)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

struct MonthViewTabs: View {
    @Binding var selectedMode: CalendarView.ViewMode

    var body: some View {
        HStack(spacing: 6) {
            MonthViewTabItem(title: "日历", isSelected: selectedMode == .calendar) {
                selectedMode = .calendar
            }
            MonthViewTabItem(title: "纵览", isSelected: selectedMode == .week) {
                selectedMode = .week
            }
        }
        .padding(6)
        .background(AppTheme.card)
        .cornerRadius(16)
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 3)
    }
}

struct MonthViewTabItem: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? AppTheme.accentOrange : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

struct MonthCalendarCard: View {
    let monthDate: Date
    @Binding var selectedDate: Date
    let plans: [Plan]
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDateSelected: () -> Void

    private let calendar = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: monthDate)
    }

    private var yearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: monthDate)
    }

    private var daysInMonth: [Date?] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(AppTheme.accentOrange)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.cardSecondary)
                        .clipShape(Circle())
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(monthName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)

                    Text(yearText)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(AppTheme.accentOrange)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.cardSecondary)
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 14) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let dayPlans = plans.filter { calendar.isDate($0.date, inSameDayAs: date) }
                        let status: DayPlanStatus = {
                            if dayPlans.isEmpty {
                                return .none
                            }
                            return dayPlans.allSatisfy { $0.isCompleted } ? .completed : .pending
                        }()
                        MonthDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            status: status,
                            onTap: {
                                selectedDate = date
                                onDateSelected()
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(AppTheme.card)
        .cornerRadius(20)
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

enum DayPlanStatus {
    case none
    case pending
    case completed
}

struct MonthDayCell: View {
    let date: Date
    let isSelected: Bool
    let status: DayPlanStatus
    let onTap: () -> Void

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(dayNumber)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(isSelected ? AppTheme.accentOrange : Color.clear)
                    )

                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
            }
            .frame(height: 46)
        }
        .buttonStyle(.plain)
    }

    private var dotColor: Color {
        switch status {
        case .none:
            return Color.clear
        case .pending:
            return AppTheme.accentOrange
        case .completed:
            return AppTheme.accentGreen
        }
    }
}

struct MonthPlanEditorSheet: View {
    @Binding var items: [GoalItem]
    @Environment(\.dismiss) private var dismiss
    @State private var localItems: [GoalItem] = []

    private let limit = 8

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            HStack {
                Text("编辑本月目标")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("\(localItems.count)/\(limit)")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(localItems.indices, id: \.self) { index in
                        YearlyGoalEditorRow(
                            item: binding(for: index),
                            placeholder: "输入本月目标...",
                            onDelete: { removeItem(at: index) }
                        )
                    }

                    Button {
                        addItem()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("新增目标")
                                .font(.headline)
                        }
                        .foregroundColor(localItems.count >= limit ? AppTheme.textSecondary : AppTheme.accentOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.cardSecondary)
                        .cornerRadius(18)
                    }
                    .disabled(localItems.count >= limit)
                }
                .padding(.horizontal, 20)
            }

            Button {
                items = localItems
                    .map { GoalItem(id: $0.id, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), isCompleted: $0.isCompleted) }
                    .filter { !$0.text.isEmpty }
                dismiss()
            } label: {
                Text("保存")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accentOrange)
                    .cornerRadius(18)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 12)
        }
        .background(AppTheme.background)
        .onAppear {
            if items.isEmpty {
                localItems = [GoalItem(text: "")]
            } else {
                localItems = Array(items.prefix(limit))
            }
        }
    }

    private func addItem() {
        guard localItems.count < limit else { return }
        localItems.append(GoalItem(text: ""))
    }

    private func removeItem(at index: Int) {
        guard localItems.indices.contains(index) else { return }
        localItems.remove(at: index)
        if localItems.isEmpty {
            localItems.append(GoalItem(text: ""))
        }
    }

    private func binding(for index: Int) -> Binding<GoalItem> {
        Binding(
            get: { localItems.indices.contains(index) ? localItems[index] : GoalItem(text: "") },
            set: { newValue in
                if localItems.indices.contains(index) {
                    let limited = String(newValue.text.prefix(GoalItem.maxTextLength))
                    localItems[index].text = limited
                    localItems[index].isCompleted = newValue.isCompleted
                }
            }
        )
    }
}

// MARK: - 快捷入口
struct CalendarQuickActions: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    @Binding var viewMode: CalendarView.ViewMode

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedDate = Date()
                    currentMonth = Date()
                    viewMode = .calendar
                }
            } label: {
                Label("今天", systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 1.0, green: 0.98, blue: 0.94))
                    .cornerRadius(10)
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedDate = Date()
                    currentMonth = Date()
                    viewMode = .week
                }
            } label: {
                Label("本周", systemImage: "rectangle.grid.1x2")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 1.0, green: 0.98, blue: 0.94))
                    .cornerRadius(10)
            }

            Spacer()

            Text(calendar.isDate(selectedDate, inSameDayAs: Date()) ? "今日" : "已选日期")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(red: 0.99, green: 0.96, blue: 0.92))
        .cornerRadius(12)
    }
}

struct CalendarPageHeader: View {
    let title: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly Plan")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.99, green: 0.96, blue: 0.92))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 视图模式选择器
struct ViewModePicker: View {
    @Binding var selectedMode: CalendarView.ViewMode
    
    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedMode = .calendar
                }
            } label: {
                Text("日历")
                    .font(.headline)
                    .foregroundColor(selectedMode == .calendar ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selectedMode == .calendar {
                                LinearGradient(
                                    colors: [Color(red: 0.86, green: 0.65, blue: 0.42), Color(red: 0.78, green: 0.55, blue: 0.34)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .cornerRadius(12, corners: [.topLeft, .bottomLeft])
            }
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedMode = .week
                }
            } label: {
                Text("周视图")
                    .font(.headline)
                    .foregroundColor(selectedMode == .week ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selectedMode == .week {
                                LinearGradient(
                                    colors: [Color(red: 0.86, green: 0.65, blue: 0.42), Color(red: 0.78, green: 0.55, blue: 0.34)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .cornerRadius(12, corners: [.topRight, .bottomRight])
            }
        }
        .background(Color(red: 0.99, green: 0.96, blue: 0.92))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 日历月视图
struct CalendarMonthView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let plans: [Plan]
    let onDateSelected: () -> Void
    
    private let calendar = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: currentMonth)
    }
    
    private var daysInMonth: [Date?] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 月份导航
                HStack {
                    Button {
                        withAnimation {
                            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.86, green: 0.65, blue: 0.42), Color(red: 0.78, green: 0.55, blue: 0.34)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Spacer()
                    
                    Text(monthYearString)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.86, green: 0.65, blue: 0.42), Color(red: 0.78, green: 0.55, blue: 0.34)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .padding(.horizontal)
                
                // 星期标题
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // 日期网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                        if let date = date {
                            CalendarDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDate(date, inSameDayAs: Date()),
                                planCount: plans.filter { calendar.isDate($0.date, inSameDayAs: date) }.count,
                                onTap: {
                                    selectedDate = date
                                    onDateSelected()
                                }
                            )
                        } else {
                            Color.clear
                                .frame(height: 50)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - 日历日期单元格
struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let planCount: Int
    let onTap: () -> Void
    
    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? Color(red: 0.75, green: 0.52, blue: 0.28) : .primary))
                
                if planCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(planCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.85) : Color(red: 0.78, green: 0.58, blue: 0.36))
                                .frame(width: 4, height: 4)
                        }
                        if planCount > 3 {
                            Text("+")
                                .font(.system(size: 8))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : Color(red: 0.78, green: 0.58, blue: 0.36))
                        }
                    }
                }
            }
            .frame(width: 50, height: 50)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [Color(red: 0.86, green: 0.65, blue: 0.42), Color(red: 0.78, green: 0.55, blue: 0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if isToday {
                        Color(red: 0.86, green: 0.73, blue: 0.55).opacity(0.35)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isToday && !isSelected ? Color(red: 0.86, green: 0.65, blue: 0.42) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 扩展：圆角指定
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 扩展：Date 作为 Identifiable
extension Date: Identifiable {
    public var id: TimeInterval {
        self.timeIntervalSince1970
    }
}
