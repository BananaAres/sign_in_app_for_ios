import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var planStore: PlanStore
    @State private var currentUser: User?
    @State private var showLoginSheet = false
    @State private var showLogoutAlert = false
    @State private var showSupportSheet = false
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("dark_mode_enabled") private var darkModeEnabled = false
    
    // 统计数据
    @State private var totalCheckInDays: Int = 0
    @State private var currentStreak: Int = 0
    @State private var badgeCount: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        ProfileHeader()

                        if authManager.isAuthenticated {
                            // 已登录状态
                            if let user = currentUser ?? authManager.currentUser {
                                ProfileInfoCard(
                                    user: user,
                                    isPro: purchaseManager.isPro,
                                    totalCheckInDays: totalCheckInDays,
                                    currentStreak: currentStreak,
                                    badgeCount: badgeCount
                                )
                            }

                            ProfileSupportCard(onTap: {
                                showSupportSheet = true
                            })

                            ProfileSettingsCard(
                                notificationsEnabled: $notificationsEnabled,
                                darkModeEnabled: $darkModeEnabled
                            )

                            ProfileOtherCard()

                            LogoutButton {
                                showLogoutAlert = true
                            }
                        } else {
                            // 未登录状态
                            NotLoggedInCard {
                                showLoginSheet = true
                            }
                            
                            ProfileSupportCard(onTap: { showSupportSheet = true })

                            ProfileSettingsCard(
                                notificationsEnabled: $notificationsEnabled,
                                darkModeEnabled: $darkModeEnabled
                            )

                            ProfileOtherCard()
                        }

                        Text("计划打卡 v1.0.0")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLoginSheet) {
                SignInView()
            }
            .sheet(isPresented: $showSupportSheet) {
                SupportDeveloperSheet()
            }
            .alert("退出登录", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("确认退出", role: .destructive) {
                    withAnimation {
                        authManager.logout()
                        currentUser = nil
                    }
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
            .task {
                if authManager.isAuthenticated {
                    currentUser = authManager.currentUser
                }
                await loadStats()
            }
            .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    currentUser = authManager.currentUser
                } else {
                    currentUser = nil
                }
            }
            .onChange(of: notificationsEnabled) { enabled in
                if !enabled {
                    NotificationManager.shared.cancelAll()
                }
            }
        }
    }
    
    // MARK: - 加载真实统计数据
    private func loadStats() async {
        let calendar = Calendar.current
        
        // 获取所有计划（从很早的时间到现在）
        let distantPast = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date.distantPast
        let plans = (try? await planStore.fetchPlans(from: distantPast, to: Date())) ?? []
        
        // 按天分组
        let dayBuckets = Dictionary(grouping: plans) { calendar.startOfDay(for: $0.startTime) }
        
        // 计算累计打卡天数（有完成计划的天数）
        let checkInDays = dayBuckets.filter { _, items in
            items.contains(where: { $0.isCompleted })
        }.count
        
        // 计算当前连续打卡天数
        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())
        while true {
            let items = dayBuckets[currentDay] ?? []
            if items.contains(where: { $0.isCompleted }) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
                currentDay = previousDay
            } else {
                break
            }
        }
        
        // 计算徽章数量（基于连续打卡天数）
        let milestones = [1, 7, 30, 100]
        let badges = milestones.filter { streak >= $0 }.count
        
        // 更新 UI
        await MainActor.run {
            totalCheckInDays = checkInDays
            currentStreak = streak
            badgeCount = badges
        }
    }
}

// MARK: - 未登录卡片
struct NotLoggedInCard: View {
    let onLogin: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 图标
            ZStack {
                Circle()
                    .fill(AppTheme.cardSecondary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accentOrange, AppTheme.accentGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("还未登录")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                
                Text("登录后可同步数据，解锁更多功能")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onLogin) {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                    Text("通过 Apple 登录")
                        .fontWeight(.semibold)
                }
                .font(.body)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accentOrange, Color(red: 0.95, green: 0.5, blue: 0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: AppTheme.accentOrange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(24)
        .background(AppTheme.card)
        .cornerRadius(20)
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

struct ProfileHeader: View {
    var body: some View {
        HStack {
            Text("我的")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Image(systemName: "gearshape")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 36, height: 36)
                .background(AppTheme.cardSecondary)
                .clipShape(Circle())
        }
    }
}

struct ProfileInfoCard: View {
    let user: User
    let isPro: Bool
    let totalCheckInDays: Int
    let currentStreak: Int
    let badgeCount: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accentOrange.opacity(0.3), AppTheme.accentGold.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Text("🐱")
                            .font(.system(size: 28))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.displayName)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        Text(isPro ? "PRO 会员" : "普通会员")
                            .font(.caption)
                            .foregroundColor(AppTheme.accentOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.cardSecondary)
                            .cornerRadius(10)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "applelogo")
                            .foregroundColor(AppTheme.textSecondary)
                        Text(user.email ?? maskAppleId(user.appleUserId))
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accentOrange)
                    .clipShape(Circle())
            }

            Divider()

            HStack {
                ProfileStatItem(value: "\(totalCheckInDays)", title: "累计打卡")
                Spacer()
                ProfileStatItem(value: "\(currentStreak)", title: "当前连续")
                Spacer()
                ProfileStatItem(value: "\(badgeCount)", title: "徽章数量")
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
    
    private func maskAppleId(_ value: String) -> String {
        guard value.count > 8 else { return value }
        let start = value.prefix(4)
        let end = value.suffix(4)
        return "\(start)••••\(end)"
    }
}

struct ProfileStatItem: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text(title)
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

struct ProfileSupportCard: View {
    var onTap: () -> Void = {}
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Text("支持我们")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.cardSecondary)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .foregroundColor(Color.pink)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("支持开发者")
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        Text("观看广告支持我们持续更新")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(16)
            .background(AppTheme.card)
            .cornerRadius(18)
            .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 支持开发者弹窗（后续接入激励广告）
struct SupportDeveloperSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pink, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                Text("感谢您的支持！")
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.textPrimary)
                
                Text("激励广告功能即将上线\n敬请期待")
                    .font(.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("知道了")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accentOrange)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct ProfileSettingsCard: View {
    @Binding var notificationsEnabled: Bool
    @Binding var darkModeEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通用设置")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 0) {
                ProfileToggleRow(
                    icon: "bell",
                    title: "消息通知",
                    isOn: $notificationsEnabled,
                    accent: AppTheme.accentGreen
                )

                Divider()

                ProfileToggleRow(
                    icon: "moon",
                    title: "深色模式",
                    isOn: $darkModeEnabled,
                    accent: AppTheme.textSecondary
                )
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

struct ProfileOtherCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("其他")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 0) {
                ProfileChevronRow(
                    icon: "questionmark.circle",
                    title: "帮助与反馈"
                )
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(18)
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

struct ProfileToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.cardSecondary)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(AppTheme.textSecondary)
                )

            Text(title)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileChevronRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.cardSecondary)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(AppTheme.textSecondary)
                )

            Text(title)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

struct LogoutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
                    .font(.headline)
            }
            .foregroundColor(Color(red: 0.86, green: 0.4, blue: 0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.card)
            .cornerRadius(18)
            .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
        .environmentObject(PurchaseManager())
        .environmentObject(PlanStore())
}
