import Foundation

enum AuthError: Error {
    case invalidUrl
    case network(Error)
    case http(statusCode: Int, body: String)
    case decode
}

final class AuthService {
    func createDeviceToken(
        apiUrl: String,
        email: String,
        password: String,
        deviceName: String
    ) async -> Result<String, AuthError> {
        guard let url = URL(string: "\(apiUrl)/api/auth/device") else {
            return .failure(.invalidUrl)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        struct Body: Encodable {
            let email: String
            let password: String
            let device_name: String
        }
        request.httpBody = try? JSONEncoder().encode(Body(email: email, password: password, device_name: deviceName))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure(.network(error))
        }

        guard let http = response as? HTTPURLResponse else {
            return .failure(.decode)
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            return .failure(.http(statusCode: http.statusCode, body: body))
        }

        struct TokenResponse: Decodable { let token: String }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            return .failure(.decode)
        }
        return .success(decoded.token)
    }
}
