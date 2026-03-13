import Foundation

struct HeartbeatResult {
    let projectName: String?
    let issueIdentifier: String?
}

enum HeartbeatSendResult {
    case success(HeartbeatResult)
    case unauthorized
    case failure
}

final class HeartbeatService {
    func send(_ heartbeat: Heartbeat, apiUrl: String, token: String) async -> HeartbeatSendResult {
        guard let url = URL(string: "\(apiUrl)/api/heartbeat") else {
#if DEBUG
            print("[Heartbeat] ❌ Invalid URL: \(apiUrl)/api/heartbeat")
#endif
            return .failure
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONEncoder().encode(heartbeat)

#if DEBUG
        print("[Heartbeat] → \(heartbeat.appName)")
#endif

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse
        else {
#if DEBUG
            print("[Heartbeat] ❌ Network error or no response")
#endif
            return .failure
        }

#if DEBUG
        print("[Heartbeat] ← HTTP \(http.statusCode)")
#endif

        if http.statusCode == 401 { return .unauthorized }

        guard (200...299).contains(http.statusCode) else {
#if DEBUG
            print("[Heartbeat] ❌ HTTP \(http.statusCode)")
#endif
            return .failure
        }

        // Response: { "data": { "project_name": "...", "issue_identifier": "..." } }
        struct Envelope: Decodable {
            struct Inner: Decodable {
                let projectName: String?
                let issueIdentifier: String?
                enum CodingKeys: String, CodingKey {
                    case projectName    = "project_name"
                    case issueIdentifier = "issue_identifier"
                }
            }
            let data: Inner
        }

        guard let parsed = try? JSONDecoder().decode(Envelope.self, from: data) else { return .failure }
        return .success(HeartbeatResult(
            projectName: parsed.data.projectName,
            issueIdentifier: parsed.data.issueIdentifier
        ))
    }

    func sendBatch(_ heartbeats: [Heartbeat], apiUrl: String, token: String) async -> Bool {
        guard let url = URL(string: "\(apiUrl)/api/heartbeat/batch") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        struct Body: Encodable { let heartbeats: [Heartbeat] }
        request.httpBody = try? JSONEncoder().encode(Body(heartbeats: heartbeats))

        guard
            let (_, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse
        else { return false }

        return (200...299).contains(http.statusCode)
    }
}
