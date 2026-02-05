import SwiftUI

// MARK: - 日历本入口（年度封面 -> 月度日历）
struct CalendarBookView: View {
    @State private var isBookOpen = false

    var body: some View {
        ZStack {
            CalendarView(onShowCover: {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                    isBookOpen = false
                }
            })
            .opacity(isBookOpen ? 1 : 0)
            .scaleEffect(isBookOpen ? 1 : 0.98)
            .allowsHitTesting(isBookOpen)

            YearBookCoverView(onOpen: {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                    isBookOpen = true
                }
            })
                .rotation3DEffect(
                    .degrees(isBookOpen ? -110 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.75
                )
                .opacity(isBookOpen ? 0 : 1)
                .allowsHitTesting(!isBookOpen)
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: isBookOpen)
    }
}

// MARK: - 年度封面
struct YearBookCoverView: View {
    let onOpen: () -> Void

    @State private var yearPlanItems: [GoalItem] = []
    @State private var showYearEditor = false

    private let calendar = Calendar.current

    private var currentYear: Int {
        calendar.component(.year, from: Date())
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(alignment: .center) {
                    Text("年度计划")
                        .font(.system(size: 24, weight: .bold))
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
                .padding(.top, 18)

                YearlyPlanCard(
                    year: currentYear,
                    title: dailyQuote,
                    items: $yearPlanItems,
                    onEdit: {
                        showYearEditor = true
                    }
                )

                Spacer(minLength: 12)

                SwipeToMonthHint(onOpen: onOpen)
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 20)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = -20
                    let predicted = value.predictedEndTranslation.width
                    if value.translation.width < threshold || predicted < -40 {
                        onOpen()
                    }
                }
        )
        .task {
            loadYearPlan()
        }
        .onChange(of: yearPlanItems) { newValue in
            saveYearPlan(newValue)
        }
        .sheet(isPresented: $showYearEditor) {
            YearlyPlanEditorSheet(items: $yearPlanItems)
                .presentationDetents([.fraction(0.7)])
        }
    }

    private func loadYearPlan() {
        let loaded = PlanTextStore.loadGoals(key: PlanTextStore.yearKey(for: Date()))
        yearPlanItems = Array(loaded.prefix(8))
        if yearPlanItems.isEmpty {
            yearPlanItems = []
        }
    }

    private func saveYearPlan(_ items: [GoalItem]) {
        PlanTextStore.saveGoals(items, key: PlanTextStore.yearKey(for: Date()))
    }

    private var dailyQuote: String {
        let today = calendar.startOfDay(for: Date())
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        let index = (dayOfYear - 1) % motivationQuotes.count
        return motivationQuotes[index]
    }

    private let motivationQuotes: [String] = [
        "不积跬步，无以至千里",
        "千里之行，始于足下",
        "志不立，天下无可成之事",
        "凡事预则立，不预则废",
        "知之者不如好之者，好之者不如乐之者",
        "业精于勤，荒于嬉",
        "不以规矩，不能成方圆",
        "君子藏器于身，待时而动",
        "学而不思则罔，思而不学则殆",
        "路虽远，行则将至",
        "事虽难，做则必成",
        "心有所向，日复一日，必有精进",
        "胜人者有力，自胜者强",
        "天行健，君子以自强不息",
        "地势坤，君子以厚德载物",
        "贵有恒，何必三更起五更睡",
        "为者常成，行者常至",
        "一寸光阴一寸金",
        "不经历风雨，怎能见彩虹",
        "有志者事竟成",
        "专注一事，必有所得",
        "自律给我自由",
        "努力是幸运的伏笔",
        "把握今天，胜过无数明天",
        "日拱一卒，功不唐捐",
        "坚持就是胜利",
        "做最好的自己",
        "你的努力，时间看得见",
        "越努力，越幸运",
        "每天进步一点点",
        "踏实做事，厚积薄发",
        "不惧慢，只怕停",
        "磨炼使人成长",
        "心若向阳，无畏风霜",
        "有梦想，就有方向",
        "信念，是通向成功的桥梁",
        "敢于开始，才有结果",
        "现在开始，永远不晚",
        "今天的坚持，是明天的实力",
        "努力从不辜负认真",
        "自律的人最自由",
        "一分耕耘，一分收获",
        "不怕路长，只怕志短",
        "目标明确，行动有力",
        "热爱可抵岁月漫长",
        "认真是成功的开始",
        "专注成就卓越",
        "把小事做好，就是不平凡",
        "梦想不是空想，而是行动",
        "勇敢迈出第一步",
        "积累决定高度",
        "保持热情，保持成长",
        "真正的强大是自我超越",
        "心有所愿，行而不辍",
        "耐心是最好的力量",
        "保持清醒，保持努力",
        "你走过的路，都会算数",
        "选择比努力更重要，努力让选择更好",
        "只要开始，就已经赢了一半",
        "越过山丘，依旧热爱生活",
        "平凡的坚持，成就不凡",
        "把今天做成最好的一天",
        "今天的行动决定明天的高度",
        "别怕慢，重要的是别停",
        "成长是每天的自我对话",
        "把时间用在值得的事上",
        "成功来自日积月累",
        "别让懒惰偷走你的梦想",
        "目标清晰，路就不迷茫",
        "保持专注，成果自然来",
        "心向远方，脚踏实地",
        "相信自己，胜过一切",
        "把热爱变成习惯",
        "向光而行，必有回响",
        "有恒心者有恒业",
        "每一次努力都是在雕刻自己",
        "今天的你比昨天更好",
        "坚定信念，终能到达",
        "让行动成为最好的语言",
        "持续行动，持续成长",
        "你可以慢，但不要停",
        "用坚持换取改变",
        "把目标拆成今天的任务",
        "小步前进也在靠近目标",
        "努力就是最好的天赋",
        "生活不止眼前，行动创造远方",
        "认真对待每一次开始",
        "越努力，越有底气",
        "永远保持学习的心态",
        "对自己负责，就是最强的动力",
        "用结果证明自己",
        "不放弃的人，运气不会差",
        "今天的专注成就明天的能力",
        "向内求，向前走",
        "坚定方向，脚踏实地",
        "宁可慢一点，也要不停下",
        "把努力做到极致",
        "目标在前，脚步不停",
        "让习惯成就自律",
        "行动胜过一切空想",
        "把今天过成你想要的样子",
        "无畏前路，步步向上",
        "愿你眼里有光，心里有梦",
        "努力的样子最美",
        "不断前行，终会抵达",
        "用心做事，时间自有答案",
        "去做，才会有结果",
        "每一天都是新的开始",
        "相信时间的力量",
        "坚持到底，收获自来",
        "把自己变强，是最好的选择"
    ]
}

struct YearlyPlanCard: View {
    let year: Int
    let title: String
    @Binding var items: [GoalItem]
    let onEdit: () -> Void

    private var displayItems: [YearlyPlanItem] {
        items.map { YearlyPlanItem(text: $0.text, isCompleted: $0.isCompleted) }
    }

    private var isPlaceholder: Bool {
        items.isEmpty
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            BookPageStack()

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.card)
                .shadow(color: AppTheme.shadow, radius: 16, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )

            RibbonView()
                .padding(.trailing, 18)

            VStack(spacing: 14) {
                SunBadge()
                    .padding(.top, -24)

                Text(String(year))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(title)
                    .font(.callout)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)

                if isPlaceholder {
                    EmptyYearlyGoalsButton {
                        onEdit()
                    }
                    .padding(.top, 28)
                } else {
                    VStack(spacing: 12) {
                        ForEach(items.indices, id: \.self) { index in
                            YearlyPlanRow(item: $items[index])
                        }
                    }
                    .padding(.top, 12)

                    EditYearlyGoalButton {
                        onEdit()
                    }
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

}

struct YearlyPlanItem {
    let text: String
    let isCompleted: Bool
}

struct YearlyPlanRow: View {
    @Binding var item: GoalItem

    var body: some View {
        Button {
            item.isCompleted.toggle()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(item.isCompleted ? AppTheme.accentOrange : Color.gray.opacity(0.6))
                    .frame(width: 10, height: 10)

                Text(item.text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(item.isCompleted ? AppTheme.textSecondary.opacity(0.6) : AppTheme.textSecondary)
                    .strikethrough(item.isCompleted, color: AppTheme.textSecondary.opacity(0.6))
                    .lineLimit(1)

                Spacer()

                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .foregroundColor(AppTheme.accentOrange)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SunBadge: View {
    @State private var rotate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accentGold)
                .frame(width: 58, height: 58)

            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(AppTheme.accentOrange)
                    .frame(width: 6, height: 14)
                    .offset(y: -36)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
        .frame(width: 72, height: 72)
        .rotationEffect(.degrees(rotate ? 360 : 0))
        .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: rotate)
        .onAppear {
            rotate = true
        }
    }
}

struct RibbonView: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.accentOrange)
                .frame(width: 18)

            Triangle()
                .fill(AppTheme.accentOrange)
                .frame(width: 22, height: 14)
                .offset(y: -2)
        }
        .padding(.top, 22)
        .padding(.bottom, 20)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct BookPageStack: View {
    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 0.92, green: 0.88, blue: 0.83))
                .frame(maxWidth: .infinity)
                .offset(x: 14, y: 12)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 0.94, green: 0.9, blue: 0.85))
                .frame(maxWidth: .infinity)
                .offset(x: 7, y: 6)
        }
    }
}

struct EditYearlyGoalButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                Text("编辑年度目标")
                    .font(.headline)
            }
            .foregroundColor(AppTheme.accentOrange)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(AppTheme.cardSecondary)
            .cornerRadius(18)
        }
    }
}

struct EmptyYearlyGoalsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                Text("编辑年度目标")
                    .font(.headline)
            }
            .foregroundColor(AppTheme.accentOrange)
            .frame(maxWidth: 220)
            .padding(.vertical, 12)
            .background(AppTheme.cardSecondary)
            .cornerRadius(22)
        }
    }
}

struct YearlyPlanEditorSheet: View {
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
                Text("编辑年度目标")
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
                            placeholder: "输入年度目标...",
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

struct YearlyGoalEditorRow: View {
    @Binding var item: GoalItem
    let placeholder: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.isCompleted.toggle()
            } label: {
                Circle()
                    .fill(item.isCompleted ? AppTheme.accentOrange : AppTheme.accentOrange.opacity(0.4))
                    .frame(width: 10, height: 10)
            }

            TextField(placeholder, text: $item.text)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)
                .textFieldStyle(.plain)
                .onChange(of: item.text) { newValue in
                    item.text = String(newValue.prefix(GoalItem.maxTextLength))
                }

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.card)
        .cornerRadius(16)
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 3)
    }
}

struct SwipeToMonthHint: View {
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .foregroundColor(AppTheme.textSecondary)

            Text("左滑进入月计划")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            onOpen()
        }
    }
}

struct CatSparkleView: View {
    @State private var animate = false

    var body: some View {
        StarShape()
            .fill(AppTheme.accentGold)
            .frame(width: 10, height: 10)
            .offset(x: animate ? 12 : -6, y: animate ? -10 : -2)
            .opacity(animate ? 1 : 0)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false), value: animate)
            .onAppear {
                animate = true
            }
            .allowsHitTesting(false)
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = 5
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.45
        var path = Path()

        for i in 0..<(points * 2) {
            let angle = Double(i) * .pi / Double(points)
            let pointRadius = i.isMultiple(of: 2) ? radius : innerRadius
            let x = center.x + CGFloat(cos(angle - .pi / 2)) * pointRadius
            let y = center.y + CGFloat(sin(angle - .pi / 2)) * pointRadius
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

struct CalendarCoverCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 1.0, green: 0.97, blue: 0.93))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.9, green: 0.8, blue: 0.65).opacity(0.5), Color(red: 0.95, green: 0.88, blue: 0.75).opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 12)
                .padding(.leading, 10)

            VStack(spacing: 16) {
                CalendarRingHeader()

                content
            }
            .padding(20)
        }
    }
}

struct CalendarRingHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CoverCalendarPreview: View {
    let date: Date

    private let calendar = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: date)
    }

    private var daysInMonth: [Date?] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(dayDate)
            }
        }
        return days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本月预览")
                    .font(.headline)
                Spacer()
                Text(monthTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                    if let day = day {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.caption2)
                            .foregroundColor(calendar.isDate(day, inSameDayAs: Date()) ? .blue : .primary)
                            .frame(height: 18)
                            .frame(maxWidth: .infinity)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(calendar.isDate(day, inSameDayAs: Date()) ? 0.15 : 0))
                            )
                    } else {
                        Color.clear
                            .frame(height: 18)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(red: 0.99, green: 0.96, blue: 0.92))
        .cornerRadius(12)
    }
}

struct YearProgressCard: View {
    let progressText: String
    let completedDays: Int
    let totalDays: Int
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("年度进度")
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            ProgressView(value: Double(completedDays), total: Double(totalDays))
                .tint(.green)

            HStack {
                Text("已完成 \(progressText)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding()
        .background(Color(red: 0.99, green: 0.96, blue: 0.92))
        .cornerRadius(16)
    }
}

struct SwipeUpHint: View {
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(.blue)
            Text("向上滑动进入本月")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height < -30 {
                        onOpen()
                    }
                }
        )
        .onTapGesture {
            onOpen()
        }
    }
}
