import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var errorMessage: String?
    @State private var showPrivacySheet = false
    @State private var hasAgreedToPolicy = false
    @State private var showAgreementAlert = false

    var body: some View {
        ZStack {
            // 背景
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部关闭按钮
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.card)
                            .clipShape(Circle())
                            .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // 主要内容区域
                VStack(spacing: 32) {
                    // Logo 和标题
                    VStack(spacing: 16) {
                        // 带动效的猫咪图标
                        AnimatedCatLogo()
                        
                        VStack(spacing: 8) {
                            Text("欢迎使用计划打卡")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("通过 Apple ID 登录，同步你的计划数据")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    
                    VStack(spacing: 16) {
                        // 错误信息
                        if let errorMessage = errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(errorMessage)
                            }
                            .font(.footnote)
                            .foregroundColor(.red)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .background(AppTheme.card)
                    .cornerRadius(20)
                    .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 6)
                    
                    Group {
                        if hasAgreedToPolicy {
                            SignInWithAppleButton(.signIn, onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            }, onCompletion: { result in
                                authManager.handleAuthorizationResult(result)
                                if case .failure = result {
                                    errorMessage = "登录失败，请重试"
                                } else {
                                    dismiss()
                                }
                            })
                            .signInWithAppleButtonStyle(.black)
                        } else {
                            Button {
                                showAgreementAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "applelogo")
                                    Text("使用 Apple 登录")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                            }
                            .background(Color.black)
                        }
                    }
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    Button {
                        if hasAgreedToPolicy {
                            authManager.loginAsGuest()
                            dismiss()
                        } else {
                            showAgreementAlert = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle")
                            Text("本地模式进入")
                                .fontWeight(.semibold)
                        }
                        .font(.body)
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.cardSecondary)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 底部协议
                VStack(spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            hasAgreedToPolicy.toggle()
                        } label: {
                            Image(systemName: hasAgreedToPolicy ? "checkmark.square.fill" : "square")
                                .foregroundColor(hasAgreedToPolicy ? AppTheme.accentOrange : AppTheme.textSecondary)
                        }
                        
                        Text("我已阅读并同意")
                            .font(.footnote)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Button("《隐私政策与用户协议》") {
                            showPrivacySheet = true
                        }
                        .font(.footnote)
                        .foregroundColor(AppTheme.accentOrange)
                    }
                    
                    if !hasAgreedToPolicy {
                        Text("请先阅读并勾选同意后再登录")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyPolicySheet()
        }
        .animation(.spring(response: 0.3), value: errorMessage)
        .alert("请先同意隐私政策与用户协议", isPresented: $showAgreementAlert) {
            Button("好的", role: .cancel) { }
        }
    }
}

// MARK: - 带动效的猫咪 Logo
struct AnimatedCatLogo: View {
    @State private var isBreathing = false
    @State private var sparklePhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 背景光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.accentOrange.opacity(0.3),
                            AppTheme.accentGold.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(isBreathing ? 1.1 : 0.95)
                .animation(
                    .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                    value: isBreathing
                )
            
            // 星星动效
            ForEach(0..<6, id: \.self) { index in
                SparkleView(
                    index: index,
                    phase: sparklePhase
                )
            }
            
            // 猫咪图片
            Image("LoginCat")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.accentOrange.opacity(0.5),
                                    AppTheme.accentGold.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: AppTheme.accentOrange.opacity(0.2), radius: 12, x: 0, y: 6)
                .scaleEffect(isBreathing ? 1.02 : 0.98)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: isBreathing
                )
        }
        .onAppear {
            isBreathing = true
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                sparklePhase = 1
            }
        }
    }
}

// MARK: - 单个星星视图
struct SparkleView: View {
    let index: Int
    let phase: CGFloat
    
    @State private var isVisible = false
    @State private var scale: CGFloat = 0
    
    private var angle: Double {
        Double(index) * 60 + Double(phase) * 360
    }
    
    private var radius: CGFloat {
        55 + CGFloat(index % 3) * 10
    }
    
    private var delay: Double {
        Double(index) * 0.3
    }
    
    private var sparkleSize: CGFloat {
        CGFloat([8, 10, 6, 12, 7, 9][index % 6])
    }
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: sparkleSize, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [AppTheme.accentGold, AppTheme.accentOrange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(scale)
            .opacity(scale > 0.5 ? 1 : scale * 2)
            .offset(
                x: cos(angle * .pi / 180) * radius,
                y: sin(angle * .pi / 180) * radius
            )
            .onAppear {
                startAnimation()
            }
    }
    
    private func startAnimation() {
        // 初始延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateSparkle()
        }
    }
    
    private func animateSparkle() {
        // 出现动画
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            scale = 1
        }
        
        // 消失动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 0
            }
        }
        
        // 循环
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            animateSparkle()
        }
    }
}

// MARK: - 流星效果（可选增强）
struct ShootingStarView: View {
    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    
    let delay: Double
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.accentGold,
                        AppTheme.accentOrange.opacity(0.5),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 30, height: 2)
            .blur(radius: 1)
            .opacity(opacity)
            .offset(x: offset, y: offset * 0.5)
            .rotationEffect(.degrees(-45))
            .onAppear {
                startAnimation()
            }
    }
    
    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animate()
        }
    }
    
    private func animate() {
        offset = -100
        opacity = 0
        
        withAnimation(.easeIn(duration: 0.1)) {
            opacity = 1
        }
        
        withAnimation(.easeOut(duration: 0.6)) {
            offset = 100
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 0
            }
        }
        
        // 循环（随机间隔）
        let nextDelay = Double.random(in: 3...6)
        DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
            animate()
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthManager.shared)
}
