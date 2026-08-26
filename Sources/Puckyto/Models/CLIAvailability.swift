import Foundation
import Combine

/// Detects whether the provider CLIs (claude / codex / gemini) are installed.
/// GUI apps launch with a restricted PATH, so besides PATH we also scan the common
/// install directories (Homebrew, npm global, nvm, ~/.local/bin).
@MainActor
final class CLIAvailability: ObservableObject {
    static let shared = CLIAvailability()

    /// nil = not checked yet; true/false = detection result
    @Published private(set) var available: [AgentProvider: Bool] = [:]

    private init() {
        refresh()
    }

    func refresh() {
        let providers = AgentProvider.allCases
        DispatchQueue.global(qos: .utility).async {
            var result: [AgentProvider: Bool] = [:]
            for provider in providers {
                result[provider] = Self.locate(provider.executable) != nil
            }
            Task { @MainActor in self.available = result }
        }
    }

    func isAvailable(_ provider: AgentProvider) -> Bool? {
        available[provider]
    }

    /// Looks for the executable; returns its full path when found.
    nonisolated static func locate(_ name: String) -> String? {
        let home = NSHomeDirectory()
        var dirs = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        dirs += [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(home)/.local/bin",
            "\(home)/bin",
            "\(home)/.npm-global/bin",
            "\(home)/.claude/local",
        ]

        // nvm: ~/.nvm/versions/node/*/bin
        let nvmRoot = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmRoot) {
            dirs += versions.map { "\(nvmRoot)/\($0)/bin" }
        }

        let fm = FileManager.default
        for dir in dirs {
            let path = (dir as NSString).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }
}
