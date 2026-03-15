import Foundation

struct DebugEntry: Identifiable {
    let id = UUID()
    let date: Date
    let text: String

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

@MainActor
final class DebugLog: ObservableObject {
    static let shared = DebugLog()

    @Published private(set) var entries: [DebugEntry] = []

    private let maxEntries = 50

    func append(_ text: String) {
        entries.append(DebugEntry(date: Date(), text: text))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
