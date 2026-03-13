import Foundation

struct ReportSummaryItem: Decodable, Identifiable {
    var id: String { projectName ?? "unknown" }
    let projectId: Int?
    let projectName: String?
    let totalDuration: Int
    let entryCount: Int

    enum CodingKeys: String, CodingKey {
        case projectId    = "project_id"
        case projectName  = "project_name"
        case totalDuration = "total_duration"
        case entryCount   = "entry_count"
    }
}

struct TeamMemberReport: Decodable, Identifiable {
    var id: Int { userId }
    let userId: Int
    let userName: String
    let totalDuration: Int
    let byProject: [ProjectSlice]

    struct ProjectSlice: Decodable, Identifiable {
        var id: String { projectName ?? "unknown" }
        let projectId: Int?
        let projectName: String?
        let totalDuration: Int

        enum CodingKeys: String, CodingKey {
            case projectId    = "project_id"
            case projectName  = "project_name"
            case totalDuration = "total_duration"
        }
    }

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case userName     = "user_name"
        case totalDuration = "total_duration"
        case byProject    = "by_project"
    }
}

final class ReportsService {
    private let api = APIClient.shared

    func summary(from: String, to: String) async throws -> [ReportSummaryItem] {
        struct Envelope: Decodable { let data: [ReportSummaryItem] }
        let env: Envelope = try await api.get("/api/reports/summary?from=\(from)&to=\(to)")
        return env.data
    }

    func team(from: String, to: String) async throws -> [TeamMemberReport] {
        struct Envelope: Decodable { let data: [TeamMemberReport] }
        let env: Envelope = try await api.get("/api/reports/team?from=\(from)&to=\(to)")
        return env.data
    }

    func exportData(from: String, to: String) async throws -> Data {
        try await api.rawGet("/api/reports/export?from=\(from)&to=\(to)")
    }

    static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
