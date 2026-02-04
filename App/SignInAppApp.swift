import SwiftUI

@main
struct SignInAppApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var planStore = PlanStore()
    @StateObject private var purchaseManager = PurchaseManager()
    private let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
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

