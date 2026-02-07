import SwiftUI

// MARK: - 周视图（网格形式，类似截图）
struct WeekGridView: View {
    @Binding var selectedDate: Date
    let plans: [Plan]
    let onPlanSelected: (Plan) -> Void
    
    private let calendar = Calendar.current
    private let hours = Array(0...23) // 全天 0:00 到 23:00
    private let timeColumnWidth: CGFloat = 48
    /// 每个时刻行高，缩小以缩短纵览总高度（原 60，现 40）
    private let rowHeight: CGFloat = 40
    private let headerHeight: CGFloat = 52
    
    private var weekDates: [Date] {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    private var weekRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        if let first = weekDates.first, let last = weekDates.last {
            return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
        }
        return ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WeekHeaderCard(
                    title: "一周专注纵览",
                    subtitle: weekRangeString,
                    onPrevious: {
                        withAnimation {
                            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                        }
                    },
                    onNext: {
                        withAnimation {
                            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                        }
                    }
                )
                .padding(.horizontal, 0)

                // 网格视图
                GeometryReader { proxy in
                    let dayColumnWidth = (proxy.size.width - timeColumnWidth) / 7
                    
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            // 表头：星期
                            HStack(spacing: 0) {
                                // 时间列标题
                                Text("时间")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(width: timeColumnWidth, height: headerHeight)
                                
                                // 日期列
                                ForEach(weekDates, id: \.self) { date in
                                    WeekDayHeader(date: date, isToday: calendar.isDate(date, inSameDayAs: Date()))
                                        .frame(width: dayColumnWidth, height: headerHeight)
                                }
                            }
                            .background(AppTheme.cardSecondary)
                            
                            // 时间行
                            ForEach(hours, id: \.self) { hour in
                                WeekTimeRow(
                                    hour: hour,
                                    weekDates: weekDates,
                                    timeColumnWidth: timeColumnWidth,
                                    dayColumnWidth: dayColumnWidth,
                                    rowHeight: rowHeight
                                )
                            }
                        }
                        
                        // 计划块（整块显示）
                        ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                            let dayPlans = plansForDate(date: date)
                            ForEach(dayPlans) { plan in
                                WeekPlanBlock(
                                    plan: plan,
                                    columnWidth: dayColumnWidth,
                                    rowHeight: rowHeight,
                                    headerHeight: headerHeight,
                                    xOffset: timeColumnWidth + CGFloat(index) * dayColumnWidth,
                                    onTap: { onPlanSelected(plan) }
                                )
                            }
                        }
                    }
                    .background(AppTheme.card)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
                    .padding(.bottom, 16)
                }
                .frame(height: headerHeight + CGFloat(hours.count) * rowHeight)
                .padding(.horizontal, 0)
            }
        }
    }
    
    private func plansForDate(date: Date) -> [Plan] {
        plans.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
}

struct WeekHeaderCard: View {
    let title: String
    let subtitle: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button(action: onNext) {
                Image(systemName: "chevron.right.circle.fill")
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 星期表头
struct WeekDayHeader: View {
    let date: Date
    let isToday: Bool
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayString)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(isToday ? Color.blue : Color.clear)
                )

            Text(weekdayString)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isToday ? Color.blue.opacity(0.08) : Color.clear)
    }
}

// MARK: - 时间行
struct WeekTimeRow: View {
    let hour: Int
    let weekDates: [Date]
    let timeColumnWidth: CGFloat
    let dayColumnWidth: CGFloat
    let rowHeight: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            // 时间标签
            Text("\(hour):00")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: timeColumnWidth, alignment: .trailing)
                .frame(height: rowHeight)
            
            // 日期单元格
            ForEach(weekDates, id: \.self) { date in
                WeekTimeCell(
                    width: dayColumnWidth,
                    height: rowHeight,
                    isEvenRow: hour.isMultiple(of: 2)
                )
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - 时间单元格
struct WeekTimeCell: View {
    let width: CGFloat
    let height: CGFloat
    let isEvenRow: Bool
    
    var body: some View {
        Rectangle()
            .fill(isEvenRow ? Color(.systemGray6).opacity(0.35) : Color.clear)
            .frame(width: width, height: height)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 1),
                alignment: .trailing
            )
}
}

// MARK: - 周视图计划块（整块显示）
struct WeekPlanBlock: View {
    let plan: Plan
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let headerHeight: CGFloat
    let xOffset: CGFloat
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    private let dayEndMinute: Int = 24 * 60
    private let horizontalInset: CGFloat = 6
    
    private var startMinuteValue: Int {
        calendar.component(.hour, from: plan.startTime) * 60
            + calendar.component(.minute, from: plan.startTime)
    }
    
    private var endMinuteValue: Int {
        let startDay = calendar.startOfDay(for: plan.startTime)
        let endDay = calendar.startOfDay(for: plan.endTime)
        let endMinutes = calendar.component(.hour, from: plan.endTime) * 60
            + calendar.component(.minute, from: plan.endTime)
        if endDay > startDay, endMinutes == 0 {
            return dayEndMinute
        }
        return endMinutes
    }
    
    private var endTimeLabel: String {
        endMinuteValue >= dayEndMinute ? "24:00" : plan.endTimeString
    }
    
    private var topOffset: CGFloat {
        let clampedStart = max(0, min(startMinuteValue, dayEndMinute))
        return headerHeight + CGFloat(clampedStart) / 60.0 * rowHeight
    }
    
    private var height: CGFloat {
        let clampedEnd = max(0, min(endMinuteValue, dayEndMinute))
        let durationMinutes = max(0, clampedEnd - startMinuteValue)
        let scaled = CGFloat(durationMinutes) / 60.0 * rowHeight
        return max(scaled, 18)
    }
    
    private var displayTitle: String {
        String(plan.title.prefix(2))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .truncationMode(.tail)
                
                Text("\(plan.startTimeString)-\(endTimeLabel)")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: max(0, columnWidth - horizontalInset), alignment: .leading)
            .frame(height: height)
            .background(plan.color.gradient)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .offset(x: xOffset + horizontalInset / 2, y: topOffset)
        .contentShape(Rectangle())
    }
}
