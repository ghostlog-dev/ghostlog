import Foundation

/// Shared HTTP client used by all services.
final class APIClient {
    static let shared = APIClient()

    private func token() throws -> String {
        guard let t = Config.shared.token else {
            throw URLError(.userAuthenticationRequired)
        }
        return t
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await request(path: path, method: "GET", body: nil as String?)
        return try decode(data)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let data = try await request(path: path, method: "POST", body: body)
        return try decode(data)
    }

    func post(_ path: String) async throws {
        _ = try await request(path: path, method: "POST", body: nil as String?)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let data = try await request(path: path, method: "PATCH", body: body)
        return try decode(data)
    }

    func delete(_ path: String) async throws {
        _ = try await request(path: path, method: "DELETE", body: nil as String?)
    }

    func rawGet(_ path: String) async throws -> Data {
        try await request(path: path, method: "GET", body: nil as String?)
    }

    // MARK: - Private

    private func request<B: Encodable>(path: String, method: String, body: B?) async throws -> Data {
        guard let url = URL(string: GhostlogURLs.api + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }
}
