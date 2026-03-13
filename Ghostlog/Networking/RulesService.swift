import Foundation

struct TrackingRule: Identifiable, Decodable {
    let id: Int
    let projectId: Int
    let type: String
    let pattern: String
    let isRegex: Bool
    let priority: Int
    let description: String?
    let scope: String   // "personal" | "team"

    var isPersonal: Bool { scope == "personal" }

    enum CodingKeys: String, CodingKey {
        case id, type, pattern, priority, description, scope
        case projectId = "project_id"
        case isRegex   = "is_regex"
    }
}

struct RuleTestResult: Decodable {
    let matched: Bool
    let matchedPortion: String?
    let projectId: Int?

    enum CodingKeys: String, CodingKey {
        case matched
        case matchedPortion = "matched_portion"
        case projectId      = "project_id"
    }
}

final class RulesService {
    private let api = APIClient.shared

    struct RuleBody: Encodable {
        let project_id: Int
        let type: String
        let pattern: String
        let is_regex: Bool
        let priority: Int
        let description: String?
        let is_personal: Bool
    }

    func fetchRules() async throws -> [TrackingRule] {
        struct Envelope: Decodable { let data: [TrackingRule] }
        let env: Envelope = try await api.get("/api/tracking-rules")
        return env.data
    }

    func create(_ body: RuleBody) async throws -> TrackingRule {
        struct Envelope: Decodable { let data: TrackingRule }
        let env: Envelope = try await api.post("/api/tracking-rules", body: body)
        return env.data
    }

    func update(id: Int, _ body: RuleBody) async throws -> TrackingRule {
        struct Envelope: Decodable { let data: TrackingRule }
        let env: Envelope = try await api.patch("/api/tracking-rules/\(id)", body: body)
        return env.data
    }

    func delete(id: Int) async throws {
        try await api.delete("/api/tracking-rules/\(id)")
    }

    func test(type: String, pattern: String, isRegex: Bool, input: String) async throws -> RuleTestResult {
        struct Body: Encodable { let type: String; let pattern: String; let is_regex: Bool; let input: String }
        struct Envelope: Decodable { let data: RuleTestResult }
        let env: Envelope = try await api.post("/api/tracking-rules/test",
                                               body: Body(type: type, pattern: pattern, is_regex: isRegex, input: input))
        return env.data
    }
}
