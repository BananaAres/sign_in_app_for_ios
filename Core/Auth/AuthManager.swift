import Foundation
import SwiftUI
import Combine
import AuthenticationServices

// MARK: - Authentication Manager
@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var showLoginSheet: Bool = false  // 用于全局显示登录页面
    
    static let shared = AuthManager()
    
    private let userKey = "auth_user"
    private let appleUserIdKey = "apple_user_id"
    
    private init() {
        loadAuthState()
    }
    
    // MARK: - Public Methods
    
    func login(user: User) {
        self.currentUser = user
        self.isAuthenticated = true
        self.showLoginSheet = false
        saveAuthState()
    }
    
    func loginAsGuest() {
        let guestId = "guest-\(UUID().uuidString)"
        let user = User(
            id: guestId,
            appleUserId: guestId,
            email: nil,
            fullName: nil,
            nickname: "游客",
            avatar: nil,
            createdAt: Date()
        )
        login(user: user)
    }
    
    func logout() {
        self.currentUser = nil
        self.isAuthenticated = false
        clearAuthState()
    }
    
    func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let appleUserId = credential.user
            let formatter = PersonNameComponentsFormatter()
            let fullNameValue = formatter.string(from: credential.fullName ?? PersonNameComponents())
            let fullName = fullNameValue.isEmpty ? nil : fullNameValue
            let email = credential.email
            
            let user = User(
                id: appleUserId,
                appleUserId: appleUserId,
                email: email ?? currentUser?.email,
                fullName: fullName ?? currentUser?.fullName,
                nickname: currentUser?.nickname,
                avatar: currentUser?.avatar,
                createdAt: currentUser?.createdAt ?? Date()
            )
            
            login(user: user)
        case .failure:
            break
        }
    }
    
    func refreshCredentialState() {
        guard let appleUserId = KeychainStore.load(account: appleUserIdKey) else {
            isAuthenticated = false
            return
        }
        
        if appleUserId.hasPrefix("guest-") {
            if currentUser == nil {
                currentUser = User(
                    id: appleUserId,
                    appleUserId: appleUserId,
                    email: nil,
                    fullName: nil,
                    nickname: "游客",
                    avatar: nil,
                    createdAt: Date()
                )
            }
            isAuthenticated = true
            return
        }
        
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: appleUserId) { [weak self] state, _ in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    if self?.currentUser == nil {
                        self?.currentUser = User(
                            id: appleUserId,
                            appleUserId: appleUserId,
                            email: nil,
                            fullName: nil,
                            nickname: nil,
                            avatar: nil,
                            createdAt: Date()
                        )
                        self?.saveAuthState()
                    }
                    self?.isAuthenticated = true
                default:
                    self?.logout()
                }
            }
        }
    }
    
    /// 检查是否需要登录，如果未登录则显示登录页面
    /// - Returns: 是否已登录
    @discardableResult
    func requireLogin() -> Bool {
        if !isAuthenticated {
            showLoginSheet = true
            return false
        }
        return true
    }
    
    // MARK: - Private Methods
    
    private func loadAuthState() {
        if let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
        }
        
        Task { @MainActor in
            refreshCredentialState()
        }
    }
    
    private func saveAuthState() {
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
            _ = KeychainStore.save(user.appleUserId, account: appleUserIdKey)
        }
    }
    
    private func clearAuthState() {
        UserDefaults.standard.removeObject(forKey: userKey)
        KeychainStore.delete(account: appleUserIdKey)
    }
}

// MARK: - Login Required View Modifier
struct LoginRequiredModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthManager
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if authManager.requireLogin() {
                    action()
                }
            }
    }
}

extension View {
    /// 在操作前检查是否已登录，未登录则显示登录页面
    func requireLogin(action: @escaping () -> Void) -> some View {
        modifier(LoginRequiredModifier(action: action))
    }
}

// MARK: - Login Required Button
struct LoginRequiredButton<Label: View>: View {
    @EnvironmentObject var authManager: AuthManager
    let action: () -> Void
    let label: () -> Label
    
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button {
            if authManager.requireLogin() {
                action()
            }
        } label: {
            label()
        }
    }
}
