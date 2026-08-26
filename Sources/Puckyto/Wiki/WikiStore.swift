import Foundation
import Combine

/// Every terminal session has its own wiki: the files
/// ~/Library/Application Support/Puck/wiki/<sessionID>/*.md on disk.
/// Being file-based, notes can be dragged straight onto a terminal.
@MainActor
final class WikiStore: ObservableObject {
    let sessionID: UUID
    @Published var notes: [WikiNote] = []
    @Published var selectedNoteURL: URL?
    @Published var draft: String = ""

    private static var cache: [UUID: WikiStore] = [:]

    static func store(for sessionID: UUID) -> WikiStore {
        if let existing = cache[sessionID] { return existing }
        let store = WikiStore(sessionID: sessionID)
        cache[sessionID] = store
        return store
    }

    private init(sessionID: UUID) {
        self.sessionID = sessionID
        reload()
    }

    var directory: URL {
        let dir = AppStore.dataDirectory
            .appendingPathComponent("wiki", isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func reload() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        notes = urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return WikiNote(url: url, title: url.deletingPathExtension().lastPathComponent, modified: modified)
            }
            .sorted { $0.modified > $1.modified }
        if selectedNoteURL == nil { selectedNoteURL = notes.first?.url }
        loadDraft()
    }

    func loadDraft() {
        guard let url = selectedNoteURL else { draft = ""; return }
        draft = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func select(_ url: URL?) {
        saveDraft()
        selectedNoteURL = url
        loadDraft()
    }

    func saveDraft() {
        guard let url = selectedNoteURL else { return }
        try? draft.write(to: url, atomically: true, encoding: .utf8)
    }

    @discardableResult
    func createNote(titled title: String) -> URL {
        let safe = title.replacingOccurrences(of: "/", with: "-")
        var url = directory.appendingPathComponent("\(safe).md")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(safe) \(counter).md")
            counter += 1
        }
        try? "# \(title)\n\n".write(to: url, atomically: true, encoding: .utf8)
        reload()
        select(url)
        return url
    }

    func deleteNote(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        if selectedNoteURL == url { selectedNoteURL = nil }
        reload()
    }
}
