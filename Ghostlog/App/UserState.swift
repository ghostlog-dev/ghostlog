import Foundation

struct GhostlogUser: Decodable {
    let id: Int
    let name: String
    let email: String
    let role: String
    let teamId: Int
    let teams: [GhostlogTeam]?

    enum CodingKeys: String, CodingKey {
        case id, name, email, role, teams
        case teamId = "team_id"
    }
}

struct GhostlogTeam: Identifiable, Decodable {
    let id: Int
    let name: String
}

@MainActor
final class UserState: ObservableObject {
    static let shared = UserState()

    @Published var user: GhostlogUser? = nil
    @Published var isLoading = false
    @Published var currentTeamId: Int? = nil

    func load() {
        guard Config.shared.isConfigured else { return }
        isLoading = true
        Task {
            struct Envelope: Decodable { let data: GhostlogUser }
            if let envelope = try? await APIClient.shared.get("/api/auth/me") as Envelope {
                user = envelope.data
                currentTeamId = envelope.data.teamId
            }
            isLoading = false
        }
    }

    func switchTeam(id: Int) {
        Task {
            struct Body: Encodable { let team_id: Int }
            struct Envelope: Decodable { let data: GhostlogUser }
            if let envelope = try? await APIClient.shared.post("/api/auth/switch-team", body: Body(team_id: id)) as Envelope {
                user = envelope.data
                currentTeamId = envelope.data.teamId
            }
        }
    }

    var currentTeamName: String? { user?.teams?.first(where: { $0.id == user?.teamId })?.name }
    var hasMultipleTeams: Bool { (user?.teams?.count ?? 0) > 1 }
}
