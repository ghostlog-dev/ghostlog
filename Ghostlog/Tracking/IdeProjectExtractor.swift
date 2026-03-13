import Foundation

enum IdeProjectExtractor {
    private static let vsCodePattern = try! NSRegularExpression(
        pattern: #"^.+\s[—–]\s(.+)\s[—–]\s(?:Visual Studio Code|Code)$"#
    )
    private static let jetBrainsPattern = try! NSRegularExpression(
        pattern: #"^(.+?)\s[–—]\s.+\s[–—]\s(?:PhpStorm|IntelliJ IDEA|WebStorm|RubyMine|PyCharm|GoLand|Rider|CLion|DataGrip|AppCode)$"#
    )
    private static let jetBrainsApps: Set<String> = [
        "phpstorm", "intellij idea", "webstorm", "rubymine",
        "pycharm", "goland", "rider", "clion", "datagrip", "appcode",
    ]
    private static let vsCodeApps: Set<String> = ["visual studio code", "code"]

    static func extract(windowTitle: String, appName: String) -> String? {
        guard !windowTitle.isEmpty else { return nil }
        let range = NSRange(windowTitle.startIndex..., in: windowTitle)

        if let match = vsCodePattern.firstMatch(in: windowTitle, range: range),
           let r = Range(match.range(at: 1), in: windowTitle) {
            return String(windowTitle[r])
        }

        if let match = jetBrainsPattern.firstMatch(in: windowTitle, range: range),
           let r = Range(match.range(at: 1), in: windowTitle) {
            return String(windowTitle[r])
        }

        let lower = appName.lowercased()
        if jetBrainsApps.contains(lower) || vsCodeApps.contains(lower) {
            let first = windowTitle
                .components(separatedBy: CharacterSet(charactersIn: "–—"))
                .first?
                .trimmingCharacters(in: .whitespaces)
            return first.flatMap { $0.isEmpty ? nil : $0 }
        }

        return nil
    }
}
