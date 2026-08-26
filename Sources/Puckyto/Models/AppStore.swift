import Foundation
import SwiftUI
import Combine

/// All persistent and runtime state of the app. Workspace/session definitions are stored
/// as JSON under ~/Library/Application Support/dev.puckyto.app.
/// The bundle id is used as the folder name so it cannot clash with other apps that
/// happen to use a plain "Puckyto" directory.
@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    // MARK: Persistent state
    /// Interface language — English by default. Changing it refreshes every view.
    @Published var language: AppLanguage = .en {
        didSet { Loc.language = language; scheduleSave() }
    }
    @Published var workspaces: [WorkspaceModel] = []
    /// Selected theme id: rawValue for built-ins ("oneDarkPro"...), "custom-<file>" for custom ones
    @Published var themeID: String = ThemeKind.oneDarkPro.rawValue { didSet { scheduleSave() } }
    /// Custom themes loaded from themes/*.json
    @Published var customThemes: [ThemeDefinition] = []
    /// Bumped when the JSON is reloaded; this is how terminals notice a changed spec under the same id
    @Published var themeVersion: Int = 0
    /// Model catalog the user edits in Settings (provider rawValue → models).
    /// A missing entry means the built-in defaults are used for that provider.
    @Published var modelCatalog: [String: [ModelOption]] = [:]

    // MARK: Selections
    @Published var selectedWorkspaceID: UUID?
    @Published var focusedSessionID: UUID?
    @Published var sidebarSection: SidebarSection = .sessions { didSet { scheduleSave() } }
    @Published var maximizedSessionID: UUID?

    // MARK: Side panel layout
    @Published var sidePanelWidth: CGFloat = 280 { didSet { scheduleSave() } }
    /// Width of the stats column on the right of the neural map
    @Published var neuralStatsWidth: CGFloat = 260 { didSet { scheduleSave() } }
    @Published var panelPin: PanelPin = .left { didSet { scheduleSave() } }
    @Published var panelCollapsed: Bool = false { didSet { scheduleSave() } }

    // MARK: Terminal font ("" = auto-detect a Nerd Font)
    @Published var terminalFontName: String = "" { didSet { scheduleSave() } }
    @Published var terminalFontSize: Double = 12.5 { didSet { scheduleSave() } }

    // MARK: Notifications and templates
    @Published var notificationsEnabled: Bool = true { didSet { scheduleSave() } }
    @Published var agentTemplates: [AgentTemplate] = AgentTemplate.defaults { didSet { scheduleSave() } }

    // MARK: Usage ledger (real tokens, day × workspace)
    @Published var usageLedger: [UsageEntry] = []

    // MARK: Send history (last 200 entries are persisted)
    @Published var sentHistory: [SentPrompt] = []

    // MARK: Quick commands and task queues
    @Published var savedPrompts: [SavedPrompt] = SavedPrompt.defaults { didSet { scheduleSave() } }
    /// session uuidString → queued tasks (the first one is sent when the agent goes idle)
    @Published var taskQueues: [String: [QueuedTask]] = [:]

    // MARK: In-terminal search (⌘F) — which session's search bar is open
    @Published var searchSessionID: UUID?

    // MARK: Dosyalar paneli
    @Published var filesRootPath: String = NSHomeDirectory()

    private var saveWork: DispatchWorkItem?
    private var statsTimer: Timer?

    nonisolated static let dataDirectory: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("dev.puckyto.app", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var stateURL: URL { Self.dataDirectory.appendingPathComponent("state.json") }

    private struct PersistedState: Codable {
        var workspaces: [WorkspaceModel]
        var theme: ThemeKind?          // backwards compatibility
        var themeID: String?           // built-in rawValue or "custom-<file>"
        var selectedWorkspaceID: UUID?
        var filesRootPath: String?
        var modelCatalog: [String: [ModelOption]]?
        var sidePanelWidth: CGFloat?
        var panelPin: PanelPin?
        var panelCollapsed: Bool?
        var notificationsEnabled: Bool?
        var agentTemplates: [AgentTemplate]?
        var usageLedger: [UsageEntry]?
        var terminalFontName: String?
        var terminalFontSize: Double?
        var savedPrompts: [SavedPrompt]?
        var taskQueues: [String: [QueuedTask]]?
        var neuralStatsWidth: CGFloat?
        var sentHistory: [SentPrompt]?
        var language: AppLanguage?
        var sidebarSection: SidebarSection?
    }

    // MARK: - Workspace helpers

    func workspaceID(containingSession id: UUID) -> UUID? {
        workspaces.first { $0.sessions.contains { $0.id == id } }?.id
    }

    /// The workspace's shared board (BOARD.md) — created with a header if missing.
    func boardURL(forWorkspace id: UUID) -> URL {
        let dir = Self.dataDirectory.appendingPathComponent("boards", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(id.uuidString).md")
        if !FileManager.default.fileExists(atPath: url.path) {
            let name = workspaces.first { $0.id == id }?.name ?? "Workspace"
            let header = Lf("# 📋 %@ — Ortak Pano\n\nAjanlar durum güncellemelerini, kararlarını ve biten işleri buraya yazar; birbirlerinin notlarını buradan okur. Her kayıt [SS:DD:sn] saat damgası taşır.\n\n", name)
            try? header.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    /// Clears the board: the file is deleted and recreated with its header.
    func resetBoard(forWorkspace id: UUID) {
        let url = boardURL(forWorkspace: id)
        try? FileManager.default.removeItem(at: url)
        _ = boardURL(forWorkspace: id)
        objectWillChange.send()
    }

    func boardURL(forSession sessionID: UUID) -> URL? {
        guard let wsID = workspaceID(containingSession: sessionID) else { return nil }
        return boardURL(forWorkspace: wsID)
    }

    /// Queue folder where a coordinator agent drops work.
    func queueDirectory(forWorkspace id: UUID) -> URL {
        let dir = Self.dataDirectory
            .appendingPathComponent("queue", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// The agent's persistent memory file (MEMORY.md) — the panel reads/writes this file.
    nonisolated static func memoryURL(forAgent agentID: UUID) -> URL {
        let dir = dataDirectory
            .appendingPathComponent("agents", isDirectory: true)
            .appendingPathComponent(agentID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("MEMORY.md")
    }

    // MARK: - Prompt delivery (single gateway: records history, expands variables)

    /// The central way to message an agent: expands {{variables}}, sends, archives.
    @discardableResult
    func sendPrompt(_ text: String, to sessionID: UUID, source: String) -> Bool {
        guard let controller = TerminalRegistry.shared.existingController(for: sessionID),
              let session = session(with: sessionID) else { return false }
        let expanded = expandVariables(in: text, controller: controller, session: session)
        controller.sendMessage(expanded)
        sentHistory.insert(
            SentPrompt(date: Date(), sessionID: sessionID, sessionName: session.name,
                       text: expanded, source: source),
            at: 0
        )
        if sentHistory.count > 200 { sentHistory.removeLast(sentHistory.count - 200) }
        scheduleSave()
        return true
    }

    /// {{folder}} → cwd, {{branch}} → git branch, {{agent}} → name, {{time}} → now.
    /// Unknown {{x}} placeholders are left as-is (the agent may infer them from context).
    private func expandVariables(in text: String, controller: TerminalController,
                                 session: TerminalSessionModel) -> String {
        guard text.contains("{{") else { return text }
        var result = text
        let cwd = controller.currentDirectory ?? session.workingDirectory
        for key in ["{{klasör}}", "{{folder}}"] {
            result = result.replacingOccurrences(of: key, with: cwd)
        }
        for key in ["{{terminal}}", "{{agent}}"] {
            result = result.replacingOccurrences(of: key, with: session.name)
        }
        for key in ["{{tarih}}", "{{time}}"] {
            result = result.replacingOccurrences(of: key, with: Self.timeFormatter.string(from: Date()))
        }
        if result.contains("{{dal}}") || result.contains("{{branch}}") {
            let branch = GitInfo.run(["branch", "--show-current"], cwd: cwd)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
            for key in ["{{dal}}", "{{branch}}"] {
                result = result.replacingOccurrences(of: key, with: branch)
            }
        }
        return result
    }

    // MARK: - Experiment log (A/B runs are appended to experiments.md)

    nonisolated static var experimentsURL: URL {
        dataDirectory.appendingPathComponent("experiments.md")
    }

    func appendExperiment(_ markdown: String) {
        let url = Self.experimentsURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? L("# 🧪 Deney Günlüğü\n\nA/B koşularının kayıtları.\n").write(to: url, atomically: true, encoding: .utf8)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(markdown.data(using: .utf8) ?? Data())
            try? handle.close()
        }
    }

    // MARK: - Task queue

    func queue(for sessionID: UUID) -> [QueuedTask] {
        taskQueues[sessionID.uuidString] ?? []
    }

    func setQueue(_ tasks: [QueuedTask], for sessionID: UUID) {
        taskQueues[sessionID.uuidString] = tasks.isEmpty ? nil : tasks
        scheduleSave()
    }

    /// Called when an agent goes idle: sends the next queued task.
    /// Does not send while the bell (awaiting approval) is ringing, so it cannot clobber claude's question.
    func advanceTaskQueue(for sessionID: UUID) {
        var tasks = queue(for: sessionID)
        guard !tasks.isEmpty,
              let controller = TerminalRegistry.shared.existingController(for: sessionID),
              controller.isAgentSessionOpen,
              !controller.needsAttention else { return }
        let next = tasks.removeFirst()
        setQueue(tasks, for: sessionID)
        _ = controller // liveness was already checked above
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.sendPrompt(next.text, to: sessionID, source: L("⏭ kuyruk"))
        }
    }

    /// A "jump to this terminal" request from a notification or the menu bar.
    func focusSession(_ sessionID: UUID) {
        if let wsID = workspaceID(containingSession: sessionID) {
            selectedWorkspaceID = wsID
        }
        focusedSessionID = sessionID
        maximizedSessionID = nil
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.identifier == nil || !$0.title.hasPrefix("dialog") }?
            .makeKeyAndOrderFront(nil)
    }

    /// Summary for the menu bar: (running, awaiting approval)
    var agentStatusCounts: (running: Int, attention: Int) {
        let controllers = TerminalRegistry.shared.allControllers()
        return (
            controllers.filter { $0.isAgentSessionOpen }.count,
            controllers.filter { $0.needsAttention }.count
        )
    }

    // MARK: - Model katalogu

    /// Selectable models for a provider: the user's edited list if present, otherwise the built-in one.
    func models(for provider: AgentProvider) -> [ModelOption] {
        if let custom = modelCatalog[provider.rawValue] { return custom }
        return provider.defaultModels
    }

    func setModels(_ list: [ModelOption], for provider: AgentProvider) {
        modelCatalog[provider.rawValue] = list
        scheduleSave()
    }

    /// Drops the user's edits and reverts to the built-in defaults.
    func resetModels(for provider: AgentProvider) {
        modelCatalog.removeValue(forKey: provider.rawValue)
        scheduleSave()
    }

    private init() {
        load()
        loadCustomThemes()
        startStatsSampling()
    }

    // MARK: - Theme resolution

    var allThemes: [ThemeDefinition] { ThemeDefinition.builtins + customThemes }

    var currentTheme: ThemeDefinition {
        allThemes.first { $0.id == themeID } ?? ThemeDefinition.builtins[0]
    }

    var themeSpec: ThemeSpec { currentTheme.spec }

    nonisolated static var themesDirectory: URL {
        let dir = dataDirectory.appendingPathComponent("themes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Reads the themes/*.json files; malformed files are skipped silently.
    func loadCustomThemes() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.themesDirectory, includingPropertiesForKeys: nil
        )) ?? []
        customThemes = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> ThemeDefinition? in
                guard let data = try? Data(contentsOf: url),
                      let file = try? JSONDecoder().decode(CustomThemeFile.self, from: data) else { return nil }
                let slug = url.deletingPathExtension().lastPathComponent
                return ThemeDefinition(
                    id: "custom-\(slug)",
                    name: file.name ?? slug,
                    spec: file.makeSpec(),
                    isBuiltin: false
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        themeVersion += 1
        // If the selected theme was deleted, fall back to the built-in default
        if !allThemes.contains(where: { $0.id == themeID }) {
            themeID = ThemeKind.oneDarkPro.rawValue
        }
    }

    /// Creates a new custom theme JSON from a copy of the current theme and selects it.
    @discardableResult
    func createCustomTheme() -> URL {
        let fm = FileManager.default
        var slug = "yeni-tema"
        var counter = 2
        while fm.fileExists(atPath: Self.themesDirectory.appendingPathComponent("\(slug).json").path) {
            slug = "yeni-tema-\(counter)"
            counter += 1
        }
        let url = Self.themesDirectory.appendingPathComponent("\(slug).json")
        let file = CustomThemeFile(name: Lf("Yeni Tema %@", counter - 1), spec: themeSpec)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(file) {
            try? data.write(to: url, options: .atomic)
        }
        loadCustomThemes()
        themeID = "custom-\(slug)"
        return url
    }

    /// Writes or clears the font in a custom theme's JSON (nil = fall back to the global setting).
    func setThemeFont(family: String?, size: Double?, forCustom definition: ThemeDefinition) {
        guard !definition.isBuiltin else { return }
        let slug = String(definition.id.dropFirst("custom-".count))
        let url = Self.themesDirectory.appendingPathComponent("\(slug).json")
        guard let data = try? Data(contentsOf: url),
              var file = try? JSONDecoder().decode(CustomThemeFile.self, from: data) else { return }
        file.fontFamily = family
        file.fontSize = size
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let out = try? encoder.encode(file) {
            try? out.write(to: url, options: .atomic)
        }
        loadCustomThemes()
    }

    /// Deletes a custom theme (the file goes to the Trash); built-ins cannot be deleted.
    func deleteCustomTheme(_ definition: ThemeDefinition) {
        guard !definition.isBuiltin else { return }
        let slug = String(definition.id.dropFirst("custom-".count))
        let url = Self.themesDirectory.appendingPathComponent("\(slug).json")
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        loadCustomThemes()
    }

    // MARK: - Convenience accessors

    var selectedWorkspace: WorkspaceModel? {
        workspaces.first { $0.id == selectedWorkspaceID } ?? workspaces.first
    }

    var selectedWorkspaceIndex: Int? {
        workspaces.firstIndex { $0.id == (selectedWorkspaceID ?? workspaces.first?.id) }
    }

    var focusedSession: TerminalSessionModel? {
        guard let ws = selectedWorkspace else { return nil }
        return ws.sessions.first { $0.id == focusedSessionID } ?? ws.sessions.first
    }

    func session(with id: UUID) -> TerminalSessionModel? {
        for ws in workspaces {
            if let s = ws.sessions.first(where: { $0.id == id }) { return s }
        }
        return nil
    }

    func binding(forSession id: UUID) -> Binding<TerminalSessionModel>? {
        guard let wi = workspaces.firstIndex(where: { $0.sessions.contains { $0.id == id } }),
              let si = workspaces[wi].sessions.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in self?.workspaces[wi].sessions[si] ?? TerminalSessionModel() },
            set: { [weak self] newValue in
                self?.workspaces[wi].sessions[si] = newValue
                self?.scheduleSave()
            }
        )
    }

    // MARK: - Workspace / session operations

    func addWorkspace(named name: String? = nil) {
        var ws = WorkspaceModel(name: name ?? "Workspace \(workspaces.count + 1)")
        ws.sessions = [TerminalSessionModel(name: "Terminal 1")]
        workspaces.append(ws)
        selectedWorkspaceID = ws.id
        focusedSessionID = ws.sessions.first?.id
        scheduleSave()
    }

    /// Sets the workspace's default folder (nil = clear it, back to the home directory).
    func setDefaultDirectory(_ path: String?, forWorkspace id: UUID) {
        guard let wi = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[wi].defaultDirectory = path
        scheduleSave()
    }

    func renameWorkspace(_ id: UUID, to name: String) {
        guard let wi = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[wi].name = name
        scheduleSave()
    }

    func removeWorkspace(_ id: UUID) {
        guard let ws = workspaces.first(where: { $0.id == id }) else { return }
        for session in ws.sessions {
            TerminalRegistry.shared.close(sessionID: session.id)
        }
        workspaces.removeAll { $0.id == id }
        if selectedWorkspaceID == id {
            selectedWorkspaceID = workspaces.first?.id
            focusedSessionID = selectedWorkspace?.sessions.first?.id
        }
        scheduleSave()
    }

    @discardableResult
    func addSession(toWorkspace id: UUID? = nil) -> TerminalSessionModel? {
        guard let wi = workspaces.firstIndex(where: { $0.id == (id ?? selectedWorkspace?.id) }) else { return nil }
        var session = TerminalSessionModel(name: nextAgentName())
        session.agent.name = session.name
        // If the workspace has a default folder, the terminal opens there
        if let dir = workspaces[wi].defaultDirectory,
           FileManager.default.fileExists(atPath: dir) {
            session.workingDirectory = dir
        }
        workspaces[wi].sessions.append(session)
        focusedSessionID = session.id
        scheduleSave()
        return session
    }

    /// Pick an unused name from the pool for a new terminal/agent.
    private static let agentNamePool = [
        "Atlas", "Vega", "Poyraz", "Nova", "Orion", "Lyra",
        "Toros", "Mira", "Kuzey", "Aras", "Yıldız", "Deniz",
    ]

    private func nextAgentName() -> String {
        let used = Set(workspaces.flatMap { $0.sessions.map(\.name) })
        if let fresh = Self.agentNamePool.first(where: { !used.contains($0) }) {
            return fresh
        }
        var n = workspaces.flatMap(\.sessions).count + 1
        while used.contains("Ajan \(n)") { n += 1 }
        return "Ajan \(n)"
    }

    func removeSession(_ id: UUID) {
        TerminalRegistry.shared.close(sessionID: id)
        for wi in workspaces.indices {
            workspaces[wi].sessions.removeAll { $0.id == id }
        }
        if focusedSessionID == id { focusedSessionID = selectedWorkspace?.sessions.first?.id }
        if maximizedSessionID == id { maximizedSessionID = nil }
        scheduleSave()
    }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            // First launch: a sample workspace
            var ws = WorkspaceModel(name: "Workspace 1")
            let isTR = Loc.language == .tr
            var t1 = TerminalSessionModel(name: isTR ? "Kaptan" : "Captain")
            t1.agent = AgentConfig(
                name: t1.name,
                emoji: "🧭",
                task: isTR
                    ? "Bu projenin genel gelişiminden sorumlusun. Kod yaz, test et, düzenle."
                    : "You own this project's overall progress. Write code, test it, refine it.",
                rules: isTR
                    ? ["Her zaman Türkçe yanıt ver", "Değişikliklerden önce kısa bir plan açıkla"]
                    : ["Outline a short plan before making changes"]
            )
            var t2 = TerminalSessionModel(name: isTR ? "Gözcü" : "Scout")
            t2.agent = AgentConfig(
                name: t2.name, emoji: "🔭",
                task: isTR ? "Test ve kod incelemesi yap." : "Handle testing and code review."
            )
            ws.sessions = [t1, t2]
            workspaces = [ws]
            selectedWorkspaceID = ws.id
            focusedSessionID = t1.id
            scheduleSave()
            return
        }
        workspaces = state.workspaces
        // Single-identity migration: "Terminal N" + a distinct agent name → keep the agent name
        for wi in workspaces.indices {
            for si in workspaces[wi].sessions.indices {
                let session = workspaces[wi].sessions[si]
                let isGeneric = session.name.range(of: "^Terminal \\d+$", options: .regularExpression) != nil
                let agentName = session.agent.name
                let agentGeneric = agentName.isEmpty || agentName.range(of: "^Ajan( \\d+)?$", options: .regularExpression) != nil
                if isGeneric && !agentGeneric {
                    workspaces[wi].sessions[si].name = agentName
                } else {
                    workspaces[wi].sessions[si].agent.name = session.name
                }
            }
        }
        // The old theme ids (nexus/cacao/espresso/forest) are gone → fall back to the default
        let storedID = state.themeID ?? state.theme?.rawValue
        themeID = storedID.flatMap { id in
            ThemeKind(rawValue: id) != nil || id.hasPrefix("custom-") ? id : nil
        } ?? ThemeKind.oneDarkPro.rawValue
        selectedWorkspaceID = state.selectedWorkspaceID ?? workspaces.first?.id
        focusedSessionID = selectedWorkspace?.sessions.first?.id
        if let path = state.filesRootPath { filesRootPath = path }
        modelCatalog = state.modelCatalog ?? [:]
        if let width = state.sidePanelWidth { sidePanelWidth = min(max(width, 220), 520) }
        panelPin = state.panelPin ?? .left
        panelCollapsed = state.panelCollapsed ?? false
        notificationsEnabled = state.notificationsEnabled ?? true
        agentTemplates = state.agentTemplates ?? AgentTemplate.defaults
        usageLedger = state.usageLedger ?? []
        terminalFontName = state.terminalFontName ?? ""
        terminalFontSize = state.terminalFontSize ?? 12.5
        savedPrompts = state.savedPrompts ?? SavedPrompt.defaults
        taskQueues = state.taskQueues ?? [:]
        if let width = state.neuralStatsWidth { neuralStatsWidth = min(max(width, 220), 460) }
        sentHistory = state.sentHistory ?? []
        language = state.language ?? .en
        Loc.language = language
        sidebarSection = state.sidebarSection ?? .sessions
    }

    func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        let state = PersistedState(
            workspaces: workspaces,
            theme: ThemeKind(rawValue: themeID) ?? .oneDarkPro,
            themeID: themeID,
            selectedWorkspaceID: selectedWorkspaceID,
            filesRootPath: filesRootPath,
            modelCatalog: modelCatalog.isEmpty ? nil : modelCatalog,
            sidePanelWidth: sidePanelWidth,
            panelPin: panelPin,
            panelCollapsed: panelCollapsed,
            notificationsEnabled: notificationsEnabled,
            agentTemplates: agentTemplates,
            usageLedger: usageLedger.isEmpty ? nil : usageLedger,
            terminalFontName: terminalFontName,
            terminalFontSize: terminalFontSize,
            savedPrompts: savedPrompts,
            taskQueues: taskQueues.isEmpty ? nil : taskQueues,
            neuralStatsWidth: neuralStatsWidth,
            sentHistory: sentHistory.isEmpty ? nil : sentHistory,
            language: language,
            sidebarSection: sidebarSection
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(state) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }

    // MARK: - Memory (RSS) sampling
    // Reads the whole process tree with a single `ps` call and sums the RSS below each
    // terminal's shell pid. Runs every 2 seconds.

    private func startStatsSampling() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in self.sampleMemory() }
        }
    }

    private func sampleMemory() {
        let controllers = TerminalRegistry.shared.allControllers()
        let pids = controllers.compactMap { $0.shellPid > 0 ? $0.shellPid : nil }
        guard !pids.isEmpty else { return }

        DispatchQueue.global(qos: .utility).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/ps")
            proc.arguments = ["-axo", "pid=,ppid=,rss="]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            guard (try? proc.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return }

            var children: [pid_t: [pid_t]] = [:]
            var rss: [pid_t: Int] = [:]
            for line in text.split(separator: "\n") {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 3,
                      let pid = pid_t(parts[0]), let ppid = pid_t(parts[1]), let kb = Int(parts[2]) else { continue }
                children[ppid, default: []].append(pid)
                rss[pid] = kb
            }

            func treeRSS(_ root: pid_t) -> Int {
                var total = rss[root] ?? 0
                for child in children[root] ?? [] { total += treeRSS(child) }
                return total
            }

            let results = Dictionary(uniqueKeysWithValues: pids.map { ($0, treeRSS($0) * 1024) })
            Task { @MainActor in
                for controller in TerminalRegistry.shared.allControllers() {
                    if let bytes = results[controller.shellPid] {
                        controller.memoryBytes = bytes
                    }
                    controller.decayActivity()
                }
                self.sampleClaudeUsage()
                self.accumulateUsageLedger()
                self.scanTaskQueues()
                self.sampleGitChanges()
            }
        }
    }

    /// Read real token usage from the session file for every terminal running a Claude agent.
    private func sampleClaudeUsage() {
        for workspace in workspaces {
            for session in workspace.sessions where session.agent.provider == .claude {
                guard let controller = TerminalRegistry.shared.existingController(for: session.id) else { continue }
                controller.sampleClaudeUsage(cwd: controller.currentDirectory ?? session.workingDirectory)
            }
        }
    }

    // MARK: - Usage ledger

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Second-precision timestamp for board entries
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Accumulates real token deltas from the controllers, broken down by day × workspace.
    private func accumulateUsageLedger() {
        let today = Self.dayFormatter.string(from: Date())
        var changed = false

        for workspace in workspaces {
            for session in workspace.sessions {
                guard let controller = TerminalRegistry.shared.existingController(for: session.id) else { continue }
                let deltaIn = controller.realInputTokens - controller.ledgeredInput
                let deltaOut = controller.realOutputTokens - controller.ledgeredOutput
                // On a session reset (restart) the counter goes backwards; skip without corrupting the ledger
                if deltaIn < 0 || deltaOut < 0 {
                    controller.ledgeredInput = controller.realInputTokens
                    controller.ledgeredOutput = controller.realOutputTokens
                    continue
                }
                guard deltaIn > 0 || deltaOut > 0 else { continue }
                controller.ledgeredInput = controller.realInputTokens
                controller.ledgeredOutput = controller.realOutputTokens

                if let idx = usageLedger.firstIndex(where: { $0.day == today && $0.workspaceID == workspace.id }) {
                    usageLedger[idx].input += deltaIn
                    usageLedger[idx].output += deltaOut
                } else {
                    usageLedger.append(UsageEntry(day: today, workspaceID: workspace.id, input: deltaIn, output: deltaOut))
                }
                changed = true
            }
        }
        if changed { scheduleSave() }
    }

    // MARK: - Git change watcher

    private var gitTick = 0

    /// Refreshes the change summary in the folders of agent-enabled terminals every 6s.
    private func sampleGitChanges() {
        gitTick += 1
        guard gitTick % 3 == 0 else { return }
        for workspace in workspaces {
            for session in workspace.sessions {
                guard let controller = TerminalRegistry.shared.existingController(for: session.id),
                      controller.isAgentSessionOpen else { continue }
                let cwd = controller.currentDirectory ?? session.workingDirectory
                DispatchQueue.global(qos: .utility).async {
                    guard GitInfo.isRepo(cwd: cwd) else { return }
                    let summary = GitInfo.diffSummary(cwd: cwd)
                    Task { @MainActor in
                        controller.gitAdded = summary.added
                        controller.gitRemoved = summary.removed
                        controller.gitChangedFiles = summary.files
                    }
                }
            }
        }
    }

    // MARK: - Coordinator task queue

    /// Delivers task files dropped by coordinator agents to their target terminals.
    /// File format: queue/<workspaceID>/task.json → {"target": "Terminal 2", "message": "..."}
    private func scanTaskQueues() {
        let fm = FileManager.default
        for workspace in workspaces {
            let dir = Self.dataDirectory
                .appendingPathComponent("queue", isDirectory: true)
                .appendingPathComponent(workspace.id.uuidString, isDirectory: true)
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }

            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let targetName = obj["target"] as? String,
                      let message = obj["message"] as? String else {
                    try? fm.moveItem(at: file, to: file.appendingPathExtension("error"))
                    continue
                }

                // Find the target terminal by its name or agent name (case-insensitive)
                let target = workspace.sessions.first {
                    $0.name.localizedCaseInsensitiveCompare(targetName) == .orderedSame ||
                    $0.agent.name.localizedCaseInsensitiveCompare(targetName) == .orderedSame
                }

                if let target, TerminalRegistry.shared.existingController(for: target.id) != nil {
                    sendPrompt(message, to: target.id, source: L("📮 koordinatör"))
                    let board = boardURL(forWorkspace: workspace.id)
                    let stamp = Self.timeFormatter.string(from: Date())
                    let note = Lf("\n> 📮 [%@] Koordinatör görevi iletildi → **%@**: %@\n", stamp, target.name, message.prefix(120))
                    if let handle = try? FileHandle(forWritingTo: board) {
                        handle.seekToEndOfFile()
                        handle.write(note.data(using: .utf8) ?? Data())
                        try? handle.close()
                    }
                    try? fm.moveItem(at: file, to: file.appendingPathExtension("done"))
                } else {
                    try? fm.moveItem(at: file, to: file.appendingPathExtension("error"))
                }
            }
        }
    }
}
