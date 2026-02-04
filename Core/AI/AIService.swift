import Foundation

protocol AIServiceProtocol {
    func decomposePlan(input: String) async throws -> [String]
}

enum AIServiceError: Error {
    case notConfigured
}

final class AIService: AIServiceProtocol {
    static let shared = AIService()
    
    private init() {}
    
    func decomposePlan(input: String) async throws -> [String] {
        throw AIServiceError.notConfigured
    }
}
