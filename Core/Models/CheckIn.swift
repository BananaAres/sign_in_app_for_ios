import Foundation

// MARK: - CheckIn Model
struct CheckIn: Identifiable, Codable {
    let id: String
    let userId: String
    let planId: String
    var occurredAt: Date
    var value: Double // 0/1 or completion percentage
    var note: String?
    var createdAt: Date
}
