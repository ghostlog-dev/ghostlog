import Foundation

struct TimeEntry: Identifiable {
    let id: Int
    let startedAt: Date
    let endedAt: Date
    let duration: Int        // seconds
    let projectId: Int?
    let projectName: String? // resolved after joining with projects
    let status: String
    let description: String?
    let issueIdentifier: String?
}

final class TodayService {
    // MARK: - Response models

    private struct EntryEnvelope: Decodable {
        let data: [RawEntry]
    }

    private struct RawEntry: Decodable {
        let id: Int
        let startedAt: String
        let endedAt: String
        let duration: Int
        let projectId: Int?
        let status: String
        let description: String?
        let issue: RawIssue?

        enum CodingKeys: String, CodingKey {
            case id
            case startedAt    = "started_at"
            case endedAt      = "ended_at"
            case duration
            case projectId    = "project_id"
            case status
            case description
            case issue
        }
    }

    private struct RawIssue: Decodable {
        let identifier: String?
    }

    private struct ProjectEnvelope: Decodable {
        let data: [RawProject]
    }

    private struct RawProject: Decodable {
        let id: Int
        let name: String
    }

    // MARK: - Fetching

    struct FetchResult {
        let entries: [TimeEntry]
        let projects: [(id: Int, name: String)]
    }

    func fetchToday() async throws -> FetchResult {
        guard let token = Config.shared.token else {
            throw URLError(.userAuthenticationRequired)
        }
        let dateStr = Self.todayString()
        async let entriesTask  = fetchEntries(date: dateStr, token: token)
        async let projectsTask = fetchProjects(token: token)
        let (rawEntries, rawProjects) = try await (entriesTask, projectsTask)
        let projectMap = Dictionary(rawProjects.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let iso = ISO8601DateFormatter()
        let entries = rawEntries.compactMap { raw -> TimeEntry? in
            guard let start = iso.date(from: raw.startedAt),
                  let end   = iso.date(from: raw.endedAt) else { return nil }
            return TimeEntry(
                id: raw.id, startedAt: start, endedAt: end,
                duration: raw.duration, projectId: raw.projectId,
                projectName: raw.projectId.flatMap { projectMap[$0] },
                status: raw.status, description: raw.description,
                issueIdentifier: raw.issue?.identifier
            )
        }
        return FetchResult(entries: entries, projects: rawProjects.map { (id: $0.id, name: $0.name) })
    }

    private func fetchEntries(date: String, token: String) async throws -> [RawEntry] {
        let url = URL(string: "\(GhostlogURLs.api)/api/time-entries/review/\(date)")!
        let data = try await get(url: url, token: token)
        return try JSONDecoder().decode(EntryEnvelope.self, from: data).data
    }

    private func fetchProjects(token: String) async throws -> [RawProject] {
        let url = URL(string: "\(GhostlogURLs.api)/api/projects")!
        let data = try await get(url: url, token: token)
        return try JSONDecoder().decode(ProjectEnvelope.self, from: data).data
    }

    func approve(id: Int) async throws {
        try await post(path: "/api/time-entries/\(id)/approve")
    }

    func unapprove(id: Int) async throws {
        try await post(path: "/api/time-entries/\(id)/unapprove")
    }

    func update(id: Int, projectId: Int?, startedAt: Date, endedAt: Date, description: String?) async throws -> TimeEntry {
        guard let token = Config.shared.token else {
            throw URLError(.userAuthenticationRequired)
        }
        let url = URL(string: "\(GhostlogURLs.api)/api/time-entries/\(id)")!
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let iso = ISO8601DateFormatter()
        struct Body: Encodable {
            let project_id: Int?
            let started_at: String
            let ended_at: String
            let description: String?
        }
        req.httpBody = try? JSONEncoder().encode(Body(
            project_id: projectId,
            started_at: iso.string(from: startedAt),
            ended_at:   iso.string(from: endedAt),
            description: description
        ))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct Envelope: Decodable { let data: RawEntry }
        let raw = try JSONDecoder().decode(Envelope.self, from: data).data
        guard let start = iso.date(from: raw.startedAt), let end = iso.date(from: raw.endedAt) else {
            throw URLError(.cannotParseResponse)
        }
        return TimeEntry(id: raw.id, startedAt: start, endedAt: end,
                        duration: raw.duration, projectId: raw.projectId,
                        projectName: nil, status: raw.status,
                        description: raw.description, issueIdentifier: raw.issue?.identifier)
    }

    func delete(id: Int) async throws {
        guard let token = Config.shared.token else {
            throw URLError(.userAuthenticationRequired)
        }
        let url = URL(string: "\(GhostlogURLs.api)/api/time-entries/\(id)")!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func post(path: String) async throws {
        guard let token = Config.shared.token else {
            throw URLError(.userAuthenticationRequired)
        }
        let url = URL(string: "\(GhostlogURLs.api)\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func get(url: URL, token: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
