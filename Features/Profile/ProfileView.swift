import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @State private var currentUser: User?
    @State private var showLoginSheet = false
    @State private var showLogoutAlert = false
    @State private var showMembershipSheet = false
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("dark_mode_enabled") private var darkModeEnabled = false
    
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
                                ProfileInfoCard(user: user, isPro: purchaseManager.isPro)
                            }

                            ProfileServiceCard(onTap: {
                                showMembershipSheet = true
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
                            
                            ProfileServiceCard(onTap: { showLoginSheet = true })

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
            .sheet(isPresented: $showMembershipSheet) {
                MembershipView()
                    .environmentObject(purchaseManager)
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
            }
            .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    currentUser = authManager.currentUser
                } else {
                    currentUser = nil
                }
            }
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
                ProfileStatItem(value: "127", title: "累计打卡")
                Spacer()
                ProfileStatItem(value: "24", title: "当前连续")
                Spacer()
                ProfileStatItem(value: "6", title: "徽章数量")
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

struct ProfileServiceCard: View {
    var onTap: () -> Void = {}
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Text("会员服务")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.cardSecondary)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "crown.fill")
                                .foregroundColor(AppTheme.accentOrange)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("升级会员")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)

                            Text("PRO")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accentOrange)
                                .cornerRadius(8)
                        }

                        Text("解锁更多功能")
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

                Divider()

                ProfileChevronRow(
                    icon: "shield",
                    title: "隐私设置"
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

                Divider()

                ProfileChevronRow(
                    icon: "info.circle",
                    title: "关于我们"
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
}
