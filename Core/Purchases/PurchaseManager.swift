import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?
    
    private let productIds = ["plan_pro_monthly"]
    private var updatesTask: Task<Void, Never>?
    
    func start() async {
        await refreshProducts()
        await refreshEntitlements()
        listenForTransactions()
    }
    
    func refreshProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: productIds)
            lastError = nil
        } catch {
            lastError = "商品加载失败"
        }
        isLoading = false
    }
    
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    lastError = "交易验证失败"
                }
            case .pending:
                lastError = "订单待处理"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "购买失败"
        }
    }
    
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "恢复购买失败"
        }
    }
    
    private func listenForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
    
    private func refreshEntitlements() async {
        var hasPro = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if productIds.contains(transaction.productID) {
                hasPro = true
                break
            }
        }
        isPro = hasPro
    }
}
