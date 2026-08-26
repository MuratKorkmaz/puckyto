import Foundation

/// Runs git queries in the background against terminal folders (without polluting the PTY).
/// Every function blocks — call them from a background queue.
enum GitInfo {
    /// Runs a git command and returns stdout (nil on failure)
    @discardableResult
    static func run(_ args: [String], cwd: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func isRepo(cwd: String) -> Bool {
        run(["rev-parse", "--is-inside-work-tree"], cwd: cwd)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    /// Summary of working-tree changes: (+lines, −lines, files).
    /// Untracked files are included in the file list too.
    static func diffSummary(cwd: String) -> (added: Int, removed: Int, files: [String]) {
        var added = 0, removed = 0
        var files: [String] = []

        if let numstat = run(["diff", "--numstat", "HEAD"], cwd: cwd) {
            for line in numstat.split(separator: "\n") {
                let parts = line.split(separator: "\t")
                guard parts.count >= 3 else { continue }
                added += Int(parts[0]) ?? 0
                removed += Int(parts[1]) ?? 0
                files.append(String(parts[2]))
            }
        }
        if let untracked = run(["ls-files", "--others", "--exclude-standard"], cwd: cwd) {
            for line in untracked.split(separator: "\n") {
                files.append(String(line) + L(" (yeni)"))
            }
        }
        return (added, removed, files)
    }

    /// Takes a snapshot without touching the working tree: `git stash create` + `store`.
    /// With the returned sha, `git restore --source=<sha> -- .` restores the tracked files.
    static func createCheckpoint(cwd: String, label: String) -> String? {
        guard isRepo(cwd: cwd) else { return nil }
        guard let sha = run(["stash", "create", label], cwd: cwd)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !sha.isEmpty else {
            // With no changes stash create returns empty → HEAD already is the checkpoint
            return run(["rev-parse", "HEAD"], cwd: cwd)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        run(["stash", "store", "-m", label, sha], cwd: cwd)
        return sha
    }
}
