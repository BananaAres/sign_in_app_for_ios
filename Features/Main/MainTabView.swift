import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PlansView()
                .tabItem {
                    Label("计划", systemImage: "calendar")
                }
                .tag(0)
            
            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(2)
        }
        .accentColor(AppTheme.accentGreen)
        .sheet(isPresented: $authManager.showLoginSheet) {
            SignInView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
        .environmentObject(PlanStore())
        .environmentObject(PurchaseManager())
}
