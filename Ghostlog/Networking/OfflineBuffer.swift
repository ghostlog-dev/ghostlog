import Foundation

final class OfflineBuffer {
    private let bufferPath: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".timetracking")
        bufferPath = dir.appendingPathComponent("buffer.json")
    }

    func append(_ heartbeat: Heartbeat) {
        var current = read()
        current.append(heartbeat)
        write(current)
    }

    func read() -> [Heartbeat] {
        guard let data = try? Data(contentsOf: bufferPath) else { return [] }
        return (try? JSONDecoder().decode([Heartbeat].self, from: data)) ?? []
    }

    func clear() {
        try? FileManager.default.removeItem(at: bufferPath)
    }

    private func write(_ heartbeats: [Heartbeat]) {
        guard let data = try? JSONEncoder().encode(heartbeats) else { return }
        try? data.write(to: bufferPath, options: .atomic)
    }
}
