import SwiftUI

// MARK: - 计划视图（使用新的日历视图）
struct PlansView: View {
    var body: some View {
        CalendarBookView()
    }
}

#Preview {
    PlansView()
        .environmentObject(AuthManager.shared)
}
