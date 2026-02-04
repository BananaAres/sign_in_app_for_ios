import SwiftUI
import StoreKit

struct MembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        MembershipHero()
                        
                        if purchaseManager.isLoading {
                            ProgressView()
                                .padding(.top, 12)
                        } else if purchaseManager.products.isEmpty {
                            EmptyProductHint()
                        } else {
                            ForEach(purchaseManager.products, id: \.id) { product in
                                MembershipProductCard(product: product) {
                                    Task {
                                        await purchaseManager.purchase(product)
                                    }
                                }
                            }
                        }
                        
                        if let error = purchaseManager.lastError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        
                        Button("恢复购买") {
                            Task {
                                await purchaseManager.restore()
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accentOrange)
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("会员服务")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await purchaseManager.refreshProducts()
        }
    }
}

private struct MembershipHero: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("升级 PRO 会员")
                .font(.title2.weight(.bold))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("解锁更多功能，支持多设备同步")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

private struct MembershipProductCard: View {
    let product: Product
    let onBuy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(product.displayName)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(product.description)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            
            HStack {
                Text(product.displayPrice)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppTheme.accentOrange)
                
                Spacer()
                
                Button("立即升级") {
                    onBuy()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accentOrange, AppTheme.accentGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

private struct EmptyProductHint: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("未配置商品")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("请在 App Store Connect 配置订阅商品后再试")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

#Preview {
    MembershipView()
        .environmentObject(PurchaseManager())
}
