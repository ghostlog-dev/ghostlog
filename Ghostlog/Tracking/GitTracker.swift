import Foundation

final class GitTracker {
    func resolveProjectPath(basename: String, searchRoots: [String]) -> String? {
        let fm = FileManager.default
        let name = basename.lowercased()
        var candidates: [String] = []

        for root in searchRoots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries {
                let path = (root as NSString).appendingPathComponent(entry)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }

                if entry.lowercased() == name { candidates.append(path) }

                // One level deeper
                guard let subs = try? fm.contentsOfDirectory(atPath: path) else { continue }
                for sub in subs {
                    let subPath = (path as NSString).appendingPathComponent(sub)
                    var isSubDir: ObjCBool = false
                    guard fm.fileExists(atPath: subPath, isDirectory: &isSubDir), isSubDir.boolValue else { continue }
                    if sub.lowercased() == name { candidates.append(subPath) }
                }
            }
        }

        let isGitRepo = { (p: String) in fm.fileExists(atPath: (p as NSString).appendingPathComponent(".git")) }
        return candidates.first(where: isGitRepo) ?? candidates.first
    }

    func gitRemote(at path: String) -> String? {
        shell("git remote get-url origin", cwd: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    func gitBranch(at path: String) -> String? {
        let branch = shell("git rev-parse --abbrev-ref HEAD", cwd: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let b = branch?.nilIfEmpty, b != "HEAD" else { return nil }
        return b
    }

    private func shell(_ command: String, cwd: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
