import Foundation

// MARK: - User Model
struct User: Identifiable, Codable {
    let id: String
    var appleUserId: String
    var email: String?
    var fullName: String?
    var nickname: String?
    var avatar: String?
    var createdAt: Date
    
    var displayName: String {
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        if let fullName, !fullName.isEmpty {
            return fullName
        }
        if let email, !email.isEmpty {
            return email
        }
        return "用户"
    }
}
