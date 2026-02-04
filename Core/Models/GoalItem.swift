import Foundation

struct GoalItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var isCompleted: Bool

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
    }

    static let maxTextLength = 14
}
