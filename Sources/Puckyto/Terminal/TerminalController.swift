import Foundation
import AppKit
import SwiftTerm

/// SwiftTerm subclass used to count PTY traffic and capture click focus.
final class PuckytoTermView: LocalProcessTerminalView {
    weak var controller: TerminalController?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        controller?.noteOutput(bytes: slice.count)
        // BEL (0x07): claude rings the bell when it wants approval or attention
        if slice.contains(0x07) { controller?.noteBell() }
    }

    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        super.send(source: source, data: data)
        controller?.noteInput(bytes: data.count)
    }
}

/// Runtime owner of a single terminal session: the SwiftTerm view, the shell
/// process, agent state and live statistics.
final class TerminalController: NSObject, ObservableObject, LocalProcessTerminalViewDelegate {
    let sessionID: UUID
    let terminalView: PuckytoTermView

    @Published var title: String = ""
    @Published var currentDirectory: String?
    @Published var running: Bool = false
    @Published var agentRunning: Bool = false
    @Published var bytesIn: Int = 0
    @Published var bytesOut: Int = 0
    @Published var memoryBytes: Int = 0
    /// Activity that decays over time (0...1), used as brightness on the neural map
    @Published var activityLevel: Double = 0
    @Published var lastActivity: Date = .distantPast
    /// The agent rang the bell (awaiting input/approval) — cleared when the user returns to the terminal
    @Published var needsAttention: Bool = false
    private var wasExecuting = false

    // Git change watcher (AppStore fills these every 6s)
    @Published var gitAdded: Int = 0
    @Published var gitRemoved: Int = 0
    @Published var gitChangedFiles: [String] = []
    /// Snapshot taken when the agent starts (git stash create) — the revert point
    @Published var checkpointSHA: String?
    /// autoStart must fire only once
    var didAutoStart = false

    // Real Claude token usage (read from the ~/.claude/projects session file)
    @Published var realInputTokens: Int = 0
    @Published var realOutputTokens: Int = 0
    /// The portion already written to the usage ledger (used by AppStore.accumulateUsageLedger)
    var ledgeredInput: Int = 0
    var ledgeredOutput: Int = 0
    private var usageFileURL: URL?
    private var usageFileOffset: UInt64 = 0
    /// The same message can be rewritten across several lines (with cumulative usage), so we
    /// keep the latest value per message id and sum those — no double counting.
    private var usageByMessage: [String: (input: Int, output: Int)] = [:]
    private var agentStartDate: Date?

    var shellPid: pid_t { terminalView.process.shellPid }

    /// Approximate token consumption (assuming 1 token ≈ 4 bytes)
    var estimatedTokens: Int { (bytesIn + bytesOut) / 4 }

    /// Whether real usage data has arrived
    var hasRealUsage: Bool { realInputTokens + realOutputTokens > 0 }

    /// The number shown on the chips: the real total from the Claude session (input+output),
    /// or the PTY estimate when no real data exists.
    var displayTokens: Int { hasRealUsage ? realInputTokens + realOutputTokens : estimatedTokens }

    /// Considered "Executing" when it produced output within the last 2 seconds.
    var isExecuting: Bool { running && Date().timeIntervalSince(lastActivity) < 2.0 }

    var onFocusRequest: ((UUID) -> Void)?

    init(session: TerminalSessionModel) {
        self.sessionID = session.id
        self.terminalView = PuckytoTermView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        super.init()
        terminalView.controller = self
        terminalView.processDelegate = self
        terminalView.font = Self.resolveTerminalFont(name: "", size: 12.5)
        bumpScrollback()
        start(in: session.workingDirectory)
    }

    // MARK: - Process management

    private func start(in directory: String) {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        let envList = env.map { "\($0.key)=\($0.value)" }
        let shell = env["SHELL"] ?? "/bin/zsh"
        let dir = FileManager.default.fileExists(atPath: directory) ? directory : NSHomeDirectory()
        terminalView.startProcess(
            executable: shell,
            args: ["-l"],
            environment: envList,
            execName: "-\(URL(fileURLWithPath: shell).lastPathComponent)",
            currentDirectory: dir
        )
        running = true
    }

    func terminate() {
        terminalView.process.terminate()
        running = false
    }

    // MARK: - Input/output

    func send(text: String) {
        terminalView.send(txt: text)
    }

    /// Types a command/message and presses Enter. TUIs (claude/codex) expect Enter as \r in
    /// raw mode; sending \n adds a newline to the message box but does NOT submit it.
    /// \r also counts as Enter in the shell (tty icrnl) — so it is the universally correct choice.
    func sendLine(_ text: String) {
        terminalView.send(txt: text + "\r")
    }

    /// Send a chat message to the agent: type the text + Enter (\r).
    func sendMessage(_ text: String) {
        let trimmed = text.hasSuffix("\n") ? String(text.dropLast()) : text
        terminalView.send(txt: trimmed + "\r")
    }

    /// Pastes a dropped file path, escaped safely for the shell.
    func paste(path: String) {
        let escaped = "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "' "
        terminalView.send(txt: escaped)
    }

    func noteOutput(bytes: Int) {
        DispatchQueue.main.async {
            self.bytesOut += bytes
            self.lastActivity = Date()
            self.activityLevel = min(1.0, self.activityLevel + Double(bytes) / 4000.0)
        }
    }

    func noteInput(bytes: Int) {
        DispatchQueue.main.async {
            self.bytesIn += bytes
            self.lastActivity = Date()
            self.activityLevel = min(1.0, self.activityLevel + 0.05)
            self.needsAttention = false // the user is typing → the attention request has been answered
        }
    }

    /// A BEL appeared in the PTY output: the agent may be waiting for input or approval.
    func noteBell() {
        DispatchQueue.main.async {
            guard self.isAgentSessionOpen else { return }
            self.needsAttention = true
            Task { @MainActor in
                let session = AppStore.shared.session(with: self.sessionID)
                Notifier.shared.notify(
                    sessionID: self.sessionID,
                    kind: "attention",
                    title: Lf("🔔 %@ onay bekliyor", session?.name ?? L("Ajan")),
                    body: L("Terminalinde girdi/onay isteniyor."),
                    minInterval: 20
                )
            }
        }
    }

    func decayActivity() {
        activityLevel *= 0.72
        if activityLevel < 0.01 { activityLevel = 0 }

        // While an agent runs, an Executing → Idle transition means the reply finished
        let nowExecuting = isExecuting
        if agentRunning, wasExecuting, !nowExecuting {
            Task { @MainActor in
                let session = AppStore.shared.session(with: self.sessionID)
                Notifier.shared.notify(
                    sessionID: self.sessionID,
                    kind: "done",
                    title: Lf("✅ %@ hazır", session?.name ?? L("Ajan")),
                    body: L("Yanıtını tamamladı, seni bekliyor."),
                    minInterval: 12
                )
            }
        }
        if agentRunning, wasExecuting, !nowExecuting {
            // If tasks are queued, send the next one
            Task { @MainActor in AppStore.shared.advanceTaskQueue(for: self.sessionID) }
        }
        wasExecuting = nowExecuting

        objectWillChange.send() // refresh derived values such as isExecuting
    }

    func requestFocus() {
        DispatchQueue.main.async {
            self.needsAttention = false
            self.onFocusRequest?(self.sessionID)
        }
    }

    // MARK: - AI agent (Claude Code CLI)

    /// Writes the agent's task/rules/memory files and starts the selected provider's CLI
    /// (claude / codex / gemini) in the terminal. When `boardURL` is given, the workspace's
    /// shared board is introduced too; coordinator agents also learn the task queue.
    func startAgent(_ agent: AgentConfig, boardURL: URL? = nil, queueDir: URL? = nil, roster: [String] = []) {
        let prompt = buildAgentPrompt(agent, boardURL: boardURL, queueDir: queueDir, roster: roster)
        launchAgent(agent, prompt: prompt)
    }

    /// Produces the exact system prompt that will be injected into the agent.
    /// startAgent and the "View Prompt" preview share this function; it also prepares
    /// the memory/wiki folders (idempotently).
    func buildAgentPrompt(_ agent: AgentConfig, boardURL: URL? = nil, queueDir: URL? = nil, roster: [String] = []) -> String {
        let agentDir = AppStore.dataDirectory
            .appendingPathComponent("agents", isDirectory: true)
            .appendingPathComponent(agent.id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        // MEMORY.md is the single source of truth: seed it only when missing — NEVER
        // clobber what the agent added when restarting.
        let memoryURL = agentDir.appendingPathComponent("MEMORY.md")
        if !FileManager.default.fileExists(atPath: memoryURL.path) {
            let header = Loc.language == .tr
                ? "# \(agent.name) — Hafıza\n\n"
                : "# \(agent.name) — Memory\n\n"
            try? (header + agent.memory).write(to: memoryURL, atomically: true, encoding: .utf8)
        }

        // Introduce the terminal's wiki folder: the agent reads the notes and records decisions there
        let wikiDir = AppStore.dataDirectory
            .appendingPathComponent("wiki", isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: wikiDir, withIntermediateDirectories: true)

        let rules = agent.rules.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let numberedRules = rules.enumerated()
            .map { "(\($0.offset + 1)) \($0.element)" }
            .joined(separator: " ")

        return Loc.language == .tr
            ? turkishPrompt(agent, memoryURL: memoryURL, wikiDir: wikiDir,
                            boardURL: boardURL, queueDir: queueDir, roster: roster,
                            rules: numberedRules)
            : englishPrompt(agent, memoryURL: memoryURL, wikiDir: wikiDir,
                            boardURL: boardURL, queueDir: queueDir, roster: roster,
                            rules: numberedRules)
    }

    private func turkishPrompt(_ agent: AgentConfig, memoryURL: URL, wikiDir: URL,
                               boardURL: URL?, queueDir: URL?, roster: [String],
                               rules: String) -> String {
        var prompt = "Sen \"\(agent.name)\" adlı bir ajansın."
        if !agent.task.isEmpty {
            prompt += " Görevin: \(agent.task)"
        }
        if !rules.isEmpty {
            prompt += " Uyman gereken kurallar: " + rules
        }
        prompt += " Kalıcı hafızan şu dosyada: \(memoryURL.path) — çalışmaya başlamadan önce oku."
        prompt += " ÖNEMLİ: kullanıcı 'hafızana kaydet/ekle' dediğinde ya da kalıcı olması gereken"
        prompt += " bir bilgi/tercih öğrendiğinde onu BU dosyaya yaz (kendi dahili hafıza aracın"
        prompt += " yerine ya da ona ek olarak) — kullanıcı bu dosyayı uygulamadan takip ediyor."
        prompt += " Bu terminalin proje wiki'si şu klasörde: \(wikiDir.path) —"
        prompt += " çalışmaya başlamadan önce oradaki markdown notlarını oku;"
        prompt += " önemli kararları, mimari notları ve öğrendiklerini aynı klasöre"
        prompt += " markdown dosyası olarak ekle ya da mevcut notları güncelle."

        if let boardURL {
            prompt += " Workspace'in ortak panosu şu dosyada: \(boardURL.path) —"
            prompt += " diğer ajanlarla koordinasyon için kullanılır. Önemli durum güncellemelerini,"
            prompt += " aldığın kararları ve tamamladığın işleri '## \(agent.name)' başlığı altında"
            prompt += " kısa maddeler halinde bu dosyaya ekle; işe başlamadan önce diğer ajanların"
            prompt += " notlarını oradan oku ve çakışan işlere girme."
            prompt += " ÖNEMLİ: panoya eklediğin her maddenin başına o anki saati [SS:DD:sn]"
            prompt += " biçiminde koy (öğrenmek için `date '+%H:%M:%S'` çalıştır) —"
            prompt += " sıralamada kimin ne zaman ne yaptığı anlaşılsın."
        }

        if agent.coordinator, let queueDir {
            prompt += " SEN KOORDİNATÖRSÜN: bu workspace'teki diğer ajanlara iş atayabilirsin."
            prompt += " Bir ajana görev göndermek için şu klasöre yeni bir .json dosyası yaz:"
            prompt += " \(queueDir.path) — biçim: {\"target\": \"<terminal veya ajan adı>\", \"message\": \"<gönderilecek görev metni>\"}."
            prompt += " Uygulama dosyayı birkaç saniye içinde algılar, mesajı hedef terminaldeki ajana iletir"
            prompt += " ve dosyayı .done uzantısıyla işaretler."
            if !roster.isEmpty {
                prompt += " Mevcut hedefler: \(roster.joined(separator: ", "))."
            }
            prompt += " Görevleri küçük ve net parçalara böl; sonuçları ortak panodan takip et."
        }
        return prompt
    }

    private func englishPrompt(_ agent: AgentConfig, memoryURL: URL, wikiDir: URL,
                               boardURL: URL?, queueDir: URL?, roster: [String],
                               rules: String) -> String {
        var prompt = "You are an agent named \"\(agent.name)\"."
        if !agent.task.isEmpty {
            prompt += " Your task: \(agent.task)"
        }
        if !rules.isEmpty {
            prompt += " Rules you must follow: " + rules
        }
        prompt += " Your persistent memory lives in this file: \(memoryURL.path) — read it before you start."
        prompt += " IMPORTANT: when the user says 'save/add to your memory', or when you learn"
        prompt += " something that should persist, write it to THIS file (instead of, or in addition"
        prompt += " to, your own built-in memory tool) — the user watches this file from the app."
        prompt += " This terminal's project wiki is in this folder: \(wikiDir.path) —"
        prompt += " read the markdown notes there before starting, and add important decisions,"
        prompt += " architecture notes and what you learn as markdown files in the same folder"
        prompt += " (or update the existing notes)."

        if let boardURL {
            prompt += " The workspace's shared board is this file: \(boardURL.path) —"
            prompt += " it is used to coordinate with the other agents. Append important status"
            prompt += " updates, decisions you made and work you finished as short bullets under"
            prompt += " a '## \(agent.name)' heading; before starting work, read the other agents'"
            prompt += " notes there and do not duplicate their work."
            prompt += " IMPORTANT: prefix every bullet you add with the current time in [HH:MM:SS]"
            prompt += " format (run `date '+%H:%M:%S'` to get it) so the ordering shows who did what and when."
        }

        if agent.coordinator, let queueDir {
            prompt += " YOU ARE THE COORDINATOR: you can assign work to the other agents in this workspace."
            prompt += " To send a task to an agent, write a new .json file into this folder:"
            prompt += " \(queueDir.path) — format: {\"target\": \"<terminal or agent name>\", \"message\": \"<task text to send>\"}."
            prompt += " The app picks the file up within a few seconds, delivers the message to the agent"
            prompt += " in the target terminal and marks the file with a .done extension."
            if !roster.isEmpty {
                prompt += " Available targets: \(roster.joined(separator: ", "))."
            }
            prompt += " Split work into small, clear pieces and track results on the shared board."
        }
        return prompt
    }

    /// Starts the agent with a prepared prompt: takes a checkpoint, resets counters, runs the command.
    private func launchAgent(_ agent: AgentConfig, prompt: String) {
        let launch = agent.provider.launchCommand(
            prompt: prompt, model: agent.model, effort: agent.effort,
            permissionMode: agent.permissionMode
        )

        // Safety: snapshot the repo before the agent starts (does not touch the working tree)
        let cwd = currentDirectory ?? NSHomeDirectory()
        DispatchQueue.global(qos: .utility).async {
            let sha = GitInfo.createCheckpoint(cwd: cwd, label: "puckyto-checkpoint \(agent.name)")
            Task { @MainActor in self.checkpointSHA = sha }
        }

        // New session: reset the real token counters, the new session file will be discovered
        agentStartDate = Date()
        usageFileURL = nil
        usageFileOffset = 0
        usageByMessage.removeAll()
        realInputTokens = 0
        realOutputTokens = 0

        runInShell(launch)
        agentRunning = true
    }

    /// Runs a command in the shell. If an AI session is open in the terminal (started by us
    /// or manually), it first closes that session (double Ctrl+C) so the command does not
    /// end up typed into its chat.
    func runInShell(_ line: String) {
        if isAgentSessionOpen {
            send(text: "\u{03}")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.send(text: "\u{03}") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { self.sendLine(line) }
        } else {
            sendLine(line)
        }
    }

    // MARK: - Claude session history

    struct PastSession: Identifiable {
        let id: String       // session UUID (the file name)
        let date: Date
        let sizeKB: Int
    }

    /// Past Claude sessions for this terminal's folder (newest first).
    func claudePastSessions(cwd: String) -> [PastSession] {
        let projectDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(Self.claudeProjectDirName(for: cwd), isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { url -> PastSession? in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                return PastSession(
                    id: url.deletingPathExtension().lastPathComponent,
                    date: values?.contentModificationDate ?? .distantPast,
                    sizeKB: (values?.fileSize ?? 0) / 1024
                )
            }
            .sorted { $0.date > $1.date }
    }

    /// Resumes a past session in the terminal.
    func resumeClaudeSession(id: String) {
        runInShell("claude --resume \(id)")
        agentRunning = true
    }

    /// Heuristic for an AI CLI session appearing to be open in the terminal:
    /// either our own flag, or the CLI name in the window title.
    var isAgentSessionOpen: Bool {
        if agentRunning { return true }
        let t = title.lowercased()
        return t.contains("claude") || t.contains("codex") || t.contains("gemini")
    }

    // MARK: - Real Claude token usage

    /// Claude Code writes every session to ~/.claude/projects/<sanitize(cwd)>/<session>.jsonl;
    /// the `message.usage` on assistant lines carries the real API token counts.
    /// This runs on the 2s statistics tick: it finds the active session file and reads only
    /// the newly appended lines (an incremental tail).
    func sampleClaudeUsage(cwd: String) {
        guard isAgentSessionOpen else { return }
        if agentStartDate == nil { agentStartDate = Date() } // a manually opened session

        let projectDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(Self.claudeProjectDirName(for: cwd), isDirectory: true)

        func mtime(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        }

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        guard let newest = files.filter({ $0.pathExtension == "jsonl" }).max(by: { mtime($0) < mtime($1) })
        else { return }

        // Do not count an old session that ended long before the agent started
        if let start = agentStartDate, mtime(newest) < start.addingTimeInterval(-120) { return }

        if usageFileURL != newest {
            usageFileURL = newest
            usageFileOffset = 0
            usageByMessage.removeAll()
        }
        tailUsageFile()
    }

    private func tailUsageFile() {
        guard let url = usageFileURL, let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        if size < usageFileOffset { // re-read from the start if the file shrank
            usageFileOffset = 0
            usageByMessage.removeAll()
        }
        guard size > usageFileOffset else { return }
        try? handle.seek(toOffset: usageFileOffset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }

        // Leave a half-written last line to the next tick
        guard let lastNewline = data.lastIndex(of: 0x0A) else { return }
        let chunk = data[data.startIndex...lastNewline]
        usageFileOffset += UInt64(chunk.count)

        for line in chunk.split(separator: 0x0A) {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }
            let input = (usage["input_tokens"] as? Int ?? 0)
                + (usage["cache_creation_input_tokens"] as? Int ?? 0)
            let output = usage["output_tokens"] as? Int ?? 0
            let messageID = (message["id"] as? String) ?? (obj["uuid"] as? String ?? UUID().uuidString)
            usageByMessage[messageID] = (input, output)
        }

        let totals = usageByMessage.values.reduce(into: (input: 0, output: 0)) {
            $0.input += $1.input
            $0.output += $1.output
        }
        if totals.input != realInputTokens || totals.output != realOutputTokens {
            realInputTokens = totals.input
            realOutputTokens = totals.output
        }
    }

    /// Returns the LAST assistant reply in the active Claude session (id + plain text).
    /// Only the last ~256KB of the file is read, so it stays fast on large sessions.
    func lastAssistantMessage() -> (id: String, text: String)? {
        guard let url = usageFileURL,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        let window: UInt64 = 262_144
        let start = size > window ? size - window : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return nil }

        for line in data.split(separator: 0x0A).reversed() {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  obj["isSidechain"] as? Bool != true,
                  let message = obj["message"] as? [String: Any],
                  let contents = message["content"] as? [[String: Any]] else { continue }
            let text = contents
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let id = (message["id"] as? String) ?? (obj["uuid"] as? String ?? "")
            return (id, text)
        }
        return nil
    }

    /// Claude Code's project folder naming: every non-alphanumeric character becomes "-"
    /// (e.g. /Users/ali/project.x → -Users-ali-project-x)
    nonisolated static func claudeProjectDirName(for cwd: String) -> String {
        String(cwd.map { $0.isLetter || $0.isNumber ? $0 : "-" })
    }

    /// Applies the terminal font (called when SwiftTermView attaches or the setting changes)
    func applyFont(_ font: NSFont) {
        if terminalView.font != font {
            terminalView.font = font
            bumpScrollback() // changing the font resets options; grow the buffer back
        }
    }

    /// SwiftTerm's default 500-line scrollback is far too small for multi-agent output —
    /// raise it to 10,000 lines. Navigate with the wheel/trackpad or the scroller on the right.
    private func bumpScrollback() {
        terminalView.getTerminal().options.scrollback = 10_000
    }

    /// With no user choice, looks for an installed Nerd Font (for p10k/starship icons),
    /// falling back to the system monospace font when none exists.
    nonisolated static func resolveTerminalFont(name: String, size: CGFloat) -> NSFont {
        if !name.isEmpty, let font = NSFont(name: name, size: size) { return font }
        let nerdCandidates = [
            "MesloLGS NF",
            "MesloLGS Nerd Font Mono",
            "Hack Nerd Font Mono",
            "JetBrainsMono Nerd Font Mono",
            "FiraCode Nerd Font Mono",
            "SauceCodePro Nerd Font Mono",
            "Symbols Nerd Font Mono",
        ]
        for candidate in nerdCandidates {
            if let font = NSFont(name: candidate, size: size) { return font }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    // Page scrolling (the ⌘↑/⌘↓ shortcuts call these)
    func pageUp() { terminalView.pageUp() }
    func pageDown() { terminalView.pageDown() }
    func scrollToBottom() { terminalView.scroll(toPosition: 1.0) }

    func applyTheme(_ spec: ThemeSpec) {
        terminalView.nativeBackgroundColor = spec.terminalBackground
        terminalView.nativeForegroundColor = spec.terminalForeground
        terminalView.caretColor = spec.cursor
        let colors = spec.ansi.map { hex -> SwiftTerm.Color in
            var v: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&v)
            return SwiftTerm.Color(
                red: UInt16((v >> 16) & 0xFF) * 257,
                green: UInt16((v >> 8) & 0xFF) * 257,
                blue: UInt16(v & 0xFF) * 257
            )
        }
        terminalView.installColors(colors)
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async { self.title = title }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        DispatchQueue.main.async {
            if let dir = directory, let url = URL(string: dir) {
                self.currentDirectory = url.path
            } else {
                self.currentDirectory = directory
            }
        }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async {
            self.running = false
            self.agentRunning = false
        }
    }
}

/// Session id → running terminal mapping. Terminal processes keep living here even
/// as the views are redrawn.
final class TerminalRegistry {
    static let shared = TerminalRegistry()
    private var controllers: [UUID: TerminalController] = [:]
    private var clickMonitor: Any?

    private init() {
        // Update the session focus when a terminal view is clicked
        // (SwiftTerm does not leave mouseDown open, so we use an event monitor)
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self, let window = event.window else { return event }
            for controller in self.controllers.values {
                let view = controller.terminalView
                guard view.window === window else { continue }
                let local = view.convert(event.locationInWindow, from: nil)
                if view.bounds.contains(local) {
                    controller.requestFocus()
                    break
                }
            }
            return event
        }
    }

    func controller(for session: TerminalSessionModel) -> TerminalController {
        if let existing = controllers[session.id] { return existing }
        let controller = TerminalController(session: session)
        controllers[session.id] = controller
        return controller
    }

    func existingController(for id: UUID) -> TerminalController? {
        controllers[id]
    }

    func allControllers() -> [TerminalController] {
        Array(controllers.values)
    }

    func close(sessionID: UUID) {
        controllers[sessionID]?.terminate()
        controllers.removeValue(forKey: sessionID)
    }
}
