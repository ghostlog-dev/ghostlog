import Foundation

/// Persists today's tracked seconds (total + per project) to ~/.timetracking/today.json.
/// Automatically resets when the calendar day changes.
final class DayStore {
    static let shared = DayStore()

    private struct Snapshot: Codable {
        var date: String              // "2026-03-12"
        var totalSeconds: Int
        var projectSeconds: [String: Int]
    }

    private let url: URL
    private var snapshot: Snapshot

    private static var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private init() {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".timetracking")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("today.json")

        // Load persisted snapshot, or start fresh
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data),
           saved.date == Self.todayString {
            snapshot = saved
        } else {
            snapshot = Snapshot(date: Self.todayString, totalSeconds: 0, projectSeconds: [:])
        }
    }

    /// Adds elapsed seconds to the total and to the given project bucket.
    func add(seconds: Int, project: String?) {
        let today = Self.todayString
        if snapshot.date != today {
            snapshot = Snapshot(date: today, totalSeconds: 0, projectSeconds: [:])
        }
        snapshot.totalSeconds += seconds
        if let p = project, !p.isEmpty {
            snapshot.projectSeconds[p, default: 0] += seconds
        }
        save()
    }

    var totalSeconds: Int { snapshot.totalSeconds }

    /// Projects sorted by most time first.
    var projectSeconds: [(name: String, seconds: Int)] {
        snapshot.projectSeconds
            .map { (name: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
