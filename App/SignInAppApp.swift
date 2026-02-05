import SwiftUI

@main
struct SignInAppApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var planStore = PlanStore()
    @StateObject private var purchaseManager = PurchaseManager()
    private let persistenceController = PersistenceController.shared
    
    init() {
        UIWindow.appearance().backgroundColor = UIColor(AppTheme.background)
        UIScrollView.appearance().backgroundColor = UIColor(AppTheme.background)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppTheme.background)
        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(AppTheme.background)
        UINavigationBar.appearance().standardAppearance = navAppearance
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                MainTabView()
                    .background(AppTheme.background)
            }
            .environmentObject(authManager)
            .environmentObject(planStore)
            .environmentObject(purchaseManager)
            .environment(\.managedObjectContext, persistenceController.viewContext)
            .task {
                await purchaseManager.start()
            }
        }
    }
}

