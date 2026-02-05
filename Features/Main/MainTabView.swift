import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                PlansView()
                    .tabItem {
                        Label("计划", systemImage: "calendar")
                    }
                    .tag(0)

                TodayView()
                    .tabItem {
                        Label("今日", systemImage: "sun.max")
                    }
                    .tag(1)
                
                StatsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar")
                    }
                    .tag(2)
                
                ProfileView()
                    .tabItem {
                        Label("我的", systemImage: "person")
                    }
                    .tag(3)
            }
            .background(AppTheme.background)
            .toolbarBackground(AppTheme.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
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
