import Foundation
import SwiftUI

// MARK: - Plan Model (重新设计：基于日期时间，无层级)
struct Plan: Identifiable, Codable {
    let id: String
    var repeatGroupId: String?
    var title: String
    var note: String?
    var startTime: Date // 开始时间（包含日期和时间）
    var endTime: Date   // 结束时间（包含日期和时间）
    var color: PlanColor // 计划颜色（用于可视化）
    var repeatMode: RepeatMode // 重复模式
    var isCompleted: Bool // 是否完成
    var createdAt: Date
    var updatedAt: Date
    
    // 计算属性：获取计划所在的日期（只取日期部分）
    var date: Date {
        Calendar.current.startOfDay(for: startTime)
    }
    
    // 计算属性：获取开始时间（只取时间部分，格式化为小时:分钟）
    var startTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startTime)
    }
    
    // 计算属性：获取结束时间（只取时间部分）
    var endTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: endTime)
    }
    
    // 计算属性：获取持续时间（小时）
    var durationHours: Double {
        endTime.timeIntervalSince(startTime) / 3600.0
    }
}

// MARK: - 计划颜色
enum PlanColor: String, Codable, CaseIterable {
    case green = "green"
    case red = "red"
    case purple = "purple"
    case yellow = "yellow"
    case teal = "teal"
    case blue = "blue"
    case orange = "orange"
    case pink = "pink"
    case brown = "brown"
    
    var color: Color {
        switch self {
        case .green: return .green
        case .red: return .red
        case .purple: return .purple
        case .yellow: return .yellow
        case .teal: return .teal
        case .blue: return .blue
        case .orange: return .orange
        case .pink: return .pink
        case .brown: return .brown
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .green:
            return LinearGradient(colors: [.green.opacity(0.8), .green.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .red:
            return LinearGradient(colors: [.red.opacity(0.8), .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple:
            return LinearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .yellow:
            return LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teal:
            return LinearGradient(colors: [.teal.opacity(0.8), .cyan.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blue:
            return LinearGradient(colors: [.blue.opacity(0.8), .indigo.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .orange:
            return LinearGradient(colors: [.orange.opacity(0.8), .red.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pink:
            return LinearGradient(colors: [.pink.opacity(0.8), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .brown:
            return LinearGradient(colors: [.brown.opacity(0.8), .orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - 重复模式
enum RepeatMode: String, Codable {
    case none = "none"           // 不重复
    case daily = "daily"         // 每天重复
    case weekdays = "weekdays"   // 工作日重复
    case weekly = "weekly"        // 当周重复（每周同一天）
    case monthly = "monthly"      // 当月重复（每月同一天）
    
    var displayName: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天重复"
        case .weekdays: return "工作日重复"
        case .weekly: return "每周重复"
        case .monthly: return "每月重复"
        }
    }
}
