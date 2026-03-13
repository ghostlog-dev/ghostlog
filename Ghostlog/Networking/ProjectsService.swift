import Foundation

struct GhostlogClient: Identifiable, Codable {
    let id: Int
    let name: String
}

struct GhostlogProject: Identifiable, Codable {
    let id: Int
    let name: String
    let clientId: Int?
    let color: String
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, color, active
        case clientId = "client_id"
    }
}

final class ProjectsService {
    // MARK: - Clients

    func fetchClients() async throws -> [GhostlogClient] {
        let data = try await get(path: "/api/clients")
        struct Envelope: Decodable { let data: [GhostlogClient] }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    func createClient(name: String) async throws -> GhostlogClient {
        struct Body: Encodable { let name: String }
        let data = try await post(path: "/api/clients", body: Body(name: name))
        struct Envelope: Decodable { let data: GhostlogClient }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    func updateClient(id: Int, name: String) async throws -> GhostlogClient {
        struct Body: Encodable { let name: String }
        let data = try await patch(path: "/api/clients/\(id)", body: Body(name: name))
        struct Envelope: Decodable { let data: GhostlogClient }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    func deleteClient(id: Int) async throws {
        try await delete(path: "/api/clients/\(id)")
    }

    // MARK: - Projects

    func fetchProjects() async throws -> [GhostlogProject] {
        let data = try await get(path: "/api/projects")
        struct Envelope: Decodable { let data: [GhostlogProject] }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    func createProject(name: String, clientId: Int?, color: String, active: Bool) async throws -> GhostlogProject {
        struct Body: Encodable {
            let name: String
            let clientId: Int?
            let color: String
            let active: Bool
            enum CodingKeys: String, CodingKey {
                case name, color, active
                case clientId = "client_id"
            }
        }
        let data = try await post(path: "/api/projects", body: Body(name: name, clientId: clientId, color: color, active: active))
        struct Envelope: Decodable { let data: GhostlogProject }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    func updateProject(id: Int, name: String, clientId: Int?, color: String, active: Bool) async throws -> GhostlogProject {
        struct Body: Encodable {
            let name: String
            let clientId: Int?
            let color: String
            let active: Bool
            enum CodingKeys: String, CodingKey {
                case name, color, active
                case clientId = "client_id"
            }
        }
        let data = try await patch(path: "/api/projects/\(id)", body: Body(name: name, clientId: clientId, color: color, active: active))
        struct Envelope: Decodable { let data: GhostlogProject }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    func deleteProject(id: Int) async throws {
        try await delete(path: "/api/projects/\(id)")
    }

    // MARK: - HTTP helpers

    private func token() throws -> String {
        guard let t = Config.shared.token else {
            throw URLError(.userAuthenticationRequired)
        }
        return t
    }

    private func get(path: String) async throws -> Data {
        let url = URL(string: GhostlogURLs.api + path)!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await execute(req)
    }

    private func post<B: Encodable>(path: String, body: B) async throws -> Data {
        let url = URL(string: GhostlogURLs.api + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        return try await execute(req)
    }

    private func patch<B: Encodable>(path: String, body: B) async throws -> Data {
        let url = URL(string: GhostlogURLs.api + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        return try await execute(req)
    }

    private func delete(path: String) async throws {
        let url = URL(string: GhostlogURLs.api + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        _ = try await execute(req)
    }

    private func execute(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
