import SwiftUI
import UniformTypeIdentifiers

/// Lays the selected workspace's terminals out in a grid (1→single, 2→side by side, 4→2x2 ...).
struct TerminalGridView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let sessions = store.selectedWorkspace?.sessions ?? []

        Group {
            if sessions.isEmpty {
                emptyState
            } else if let maxID = store.maximizedSessionID,
                      let session = sessions.first(where: { $0.id == maxID }) {
                TerminalPaneView(session: session)
                    .padding(8)
            } else {
                grid(for: sessions)
            }
        }
    }

    private func grid(for sessions: [TerminalSessionModel]) -> some View {
        let columns = sessions.count <= 1 ? 1 : (sessions.count <= 4 ? 2 : 3)
        let rows = stride(from: 0, to: sessions.count, by: columns).map {
            Array(sessions[$0..<min($0 + columns, sessions.count)])
        }
        return VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex]) { session in
                        TerminalPaneView(session: session)
                    }
                }
            }
        }
        .padding(8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 42))
                .foregroundStyle(.tertiary)
            Text(L("Bu workspace'te terminal yok"))
                .foregroundStyle(.secondary)
            Button {
                store.addSession()
            } label: {
                Label(L("Terminal Ekle"), systemImage: "plus")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single terminal pane: header bar + SwiftTerm + drag-and-drop target.
struct TerminalPaneView: View {
    let session: TerminalSessionModel
    @EnvironmentObject var store: AppStore
    @ObservedObject private var controller: TerminalController
    @State private var isDropTargeted = false
    @Environment(\.openWindow) private var openWindow
    @State private var isEditingName = false
    @State private var nameDraft = ""
    @State private var searchText = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var searchFieldFocused: Bool

    init(session: TerminalSessionModel) {
        self.session = session
        self.controller = TerminalRegistry.shared.controller(for: session)
    }

    private var isFocused: Bool { store.focusedSessionID == session.id }
    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.searchSessionID == session.id {
                searchBar
            }
            SwiftTermView(
                controller: controller,
                themeKey: "\(store.themeID)#\(store.themeVersion)#\(store.terminalFontName)#\(store.terminalFontSize)",
                spec: store.themeSpec,
                font: TerminalController.resolveTerminalFont(
                    name: store.themeSpec.fontName ?? store.terminalFontName,
                    size: store.themeSpec.fontSize ?? store.terminalFontSize
                )
            )
        }
        .background(theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isDropTargeted ? theme.accent :
                        (isFocused ? theme.accent.opacity(0.65) : theme.panelBorder),
                    lineWidth: isDropTargeted ? 2 : 1
                )
        )
        .onAppear {
            controller.onFocusRequest = { id in store.focusedSessionID = id }
            // "Start the agent when the terminal opens" — slightly delayed so the shell can settle
            if session.agent.autoStart, !controller.didAutoStart, !controller.isAgentSessionOpen {
                controller.didAutoStart = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    startAgentWithContext()
                }
            }
        }
        .onTapGesture { store.focusedSessionID = session.id }
        .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            StatusDot(active: controller.isExecuting, color: theme.accent)

            if isEditingName {
                TextField(L("Terminal adı"), text: $nameDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 130)
                    .focused($nameFieldFocused)
                    .onSubmit(commitRename)
                    .onExitCommand { isEditingName = false }
                    .onChange(of: nameFieldFocused) { _, focused in
                        if !focused { commitRename() }
                    }
            } else {
                Text("\(session.agent.emoji) \(session.name)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .onTapGesture(count: 2) { beginRename() }
                    .help(L("Yeniden adlandırmak için çift tıkla"))
            }

            Chip(
                text: controller.isExecuting ? "Executing" : (controller.running ? "Idle" : L("Kapandı")),
                tint: controller.isExecuting ? theme.accent : .gray
            )

            // Provider tag: each AI in its own brand color
            Chip(text: session.agent.provider.tag, tint: session.agent.provider.color)

            if controller.needsAttention {
                Chip(text: L("🔔 onay bekliyor"), tint: .yellow)
                    .help(L("Ajan zil çaldı — girdi/onay bekliyor olabilir"))
            }

            if !conflictNames.isEmpty {
                Chip(text: L("⚠️ aynı klasör"), tint: .red)
                    .help(Lf("Aynı klasörde ajan çalıştıran diğer terminaller: %@. Çakışmayı önlemek için sağ tık → Git Worktree Aç.", conflictNames.joined(separator: ", ")))
            }

            if !controller.gitChangedFiles.isEmpty {
                Chip(text: "Δ +\(controller.gitAdded) −\(controller.gitRemoved)", tint: .orange)
                    .help(L("Değişen dosyalar:\n") + controller.gitChangedFiles.prefix(20).joined(separator: "\n")
                          + (controller.checkpointSHA != nil ? L("\n\nSağ tık → Checkpoint'e Geri Dön") : ""))
            }

            if !store.queue(for: session.id).isEmpty {
                Chip(text: "⏭ \(store.queue(for: session.id).count)", tint: theme.accent)
                    .help(Lf("Görev kuyruğunda %@ iş bekliyor — ajan boşa düşünce sıradaki gönderilir", store.queue(for: session.id).count))
            }

            if !controller.title.isEmpty {
                Text(controller.title)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Chip(
                text: "\(controller.hasRealUsage ? "✓" : "≈") \(formatTokens(controller.displayTokens)) tok",
                tint: theme.accent.opacity(0.9)
            )
            .help(controller.hasRealUsage
                  ? Lf("Gerçek Claude kullanımı — giriş: %@, çıkış: %@", formatTokens(controller.realInputTokens), formatTokens(controller.realOutputTokens))
                  : L("PTY trafiğinden tahmini (~4 bayt/token). Claude ajanı başlayınca gerçek sayıya döner."))

            Menu {
                ForEach(store.savedPrompts) { prompt in
                    Button(prompt.title) {
                        store.sendPrompt(prompt.text, to: session.id, source: L("⚡ hızlı"))
                        store.focusedSessionID = session.id
                    }
                }
                Divider()
                Button(L("Komutları Düzenle...")) { openWindow(id: "dialog-prompts") }
            } label: {
                Image(systemName: "bolt.fill")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(theme.textSecondary)
            .help(L("Hızlı komut gönder"))

            Button {
                startAgentWithContext()
            } label: {
                Image(systemName: "brain")
            }
            .buttonStyle(.plain)
            .foregroundStyle(controller.agentRunning ? theme.accent : theme.textSecondary)
            .help(Lf("Ajanı başlat (%@)", session.agent.provider.executable))

            Button {
                store.maximizedSessionID = store.maximizedSessionID == session.id ? nil : session.id
            } label: {
                Image(systemName: store.maximizedSessionID == session.id
                      ? "arrow.down.right.and.arrow.up.left"
                      : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .help(L("Büyüt / küçült"))

            Button {
                store.removeSession(session.id)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .help(L("Terminali kapat"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.panel)
        .contentShape(Rectangle())
        .onTapGesture { store.focusedSessionID = session.id }
        .contextMenu {
            Button(L("Sistem Promptunu Görüntüle...")) { openWindow(id: "dialog-prompt", value: session.id) }
            Button(L("CLAUDE.md Düzenle...")) { openWindow(id: "dialog-claudemd", value: session.id) }
            if session.agent.provider == .claude {
                Menu(L("Son Yanıt")) {
                    Button(L("Kopyala")) {
                        if let reply = controller.lastAssistantMessage()?.text {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(reply, forType: .string)
                        }
                    }
                    Button(L("Wiki'ye Kaydet")) { saveReplyToWiki() }
                    Menu(L("Başka Ajana İlet")) {
                        ForEach(store.workspaces.flatMap(\.sessions).filter { $0.id != session.id }) { other in
                            Button("\(other.agent.emoji) \(other.name)") { forwardReply(to: other) }
                        }
                    }
                }
            }
            Divider()
            Button(L("Görev Kuyruğu...")) { openWindow(id: "dialog-queue", value: session.id) }
            Button(L("Git Worktree Aç (izole çalış)")) { openWorktree() }
            Button(L("Claude Oturum Geçmişi...")) { openWindow(id: "dialog-history", value: session.id) }
            if let sha = controller.checkpointSHA {
                Button(L("⏪ Checkpoint'e Geri Dön (izlenen dosyalar)")) {
                    controller.runInShell("git restore --source=\(sha) -- . && git status --short")
                }
            }
        }
    }

    /// Other terminals running agents in the same folder (conflict risk)
    private var conflictNames: [String] {
        guard controller.isAgentSessionOpen else { return [] }
        let myDir = controller.currentDirectory ?? session.workingDirectory
        var names: [String] = []
        for workspace in store.workspaces {
            for other in workspace.sessions where other.id != session.id {
                guard let otherController = TerminalRegistry.shared.existingController(for: other.id),
                      otherController.isAgentSessionOpen else { continue }
                let otherDir = otherController.currentDirectory ?? other.workingDirectory
                if otherDir == myDir { names.append(other.name) }
            }
        }
        return names
    }

    private func startAgentWithContext() {
        let workspaceID = store.workspaceID(containingSession: session.id)
        var agent = session.agent
        agent.name = session.name // single identity: terminal name = agent name
        controller.startAgent(
            agent,
            boardURL: store.boardURL(forSession: session.id),
            queueDir: session.agent.coordinator && workspaceID != nil
                ? store.queueDirectory(forWorkspace: workspaceID!) : nil,
            roster: store.workspaces.first { $0.id == workspaceID }?.sessions
                .filter { $0.id != session.id }
                .map(\.name) ?? []
        )
    }

    /// Moves the agent into an isolated git worktree: new branch + sibling folder + cd
    private func openWorktree() {
        let safe = String(session.name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
        let cmd = "sfx=$RANDOM; wt=\"../$(basename \"$PWD\")-\(safe)-$sfx\" && " +
                  "git worktree add -b puckyto/\(safe)-$sfx \"$wt\" && cd \"$wt\" && " +
                  "echo \"✅ worktree: $PWD\" || echo \"⚠️ \(L("worktree açılamadı (git repo mu?)"))\""
        controller.runInShell(cmd)
    }

    /// The ⌘F search bar, built on SwiftTerm's findNext/findPrevious API
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(theme.textSecondary)
            TextField(L("Terminalde ara..."), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($searchFieldFocused)
                .onSubmit { _ = controller.terminalView.findNext(searchText) }
            Button {
                _ = controller.terminalView.findPrevious(searchText)
            } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
            Button {
                _ = controller.terminalView.findNext(searchText)
            } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
            Button {
                controller.terminalView.clearSearch()
                store.searchSessionID = nil
            } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.background.opacity(0.8))
        .onAppear { searchFieldFocused = true }
    }

    /// Save the last reply into this terminal's wiki as a timestamped note
    private func saveReplyToWiki() {
        guard let reply = controller.lastAssistantMessage()?.text else { return }
        let stamp = Date().formatted(date: .omitted, time: .standard).replacingOccurrences(of: ":", with: ".")
        let dir = AppStore.dataDirectory
            .appendingPathComponent("wiki", isDirectory: true)
            .appendingPathComponent(session.id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(Lf("Yanıt %@.md", stamp))
        try? Lf("# %@ yanıtı — %@\n\n%@\n", session.name, stamp, reply).write(to: url, atomically: true, encoding: .utf8)
        WikiStore.store(for: session.id).reload()
    }

    /// Forward the last reply, tagged with its source, to another agent's terminal (agent chaining)
    private func forwardReply(to other: TerminalSessionModel) {
        guard let reply = controller.lastAssistantMessage()?.text else { return }
        let message = Lf("**%@** ajanından iletilen yanıt aşağıda — bunu değerlendir/işle:\n\n%@", session.name, reply)
        store.sendPrompt(message, to: other.id, source: L("🔗 zincir"))
    }

    private func beginRename() {
        nameDraft = session.name
        isEditingName = true
        nameFieldFocused = true
    }

    private func commitRename() {
        guard isEditingName else { return }
        isEditingName = false
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != session.name else { return }
        store.binding(forSession: session.id)?.wrappedValue.name = trimmed
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        controller.paste(path: url.path)
                        store.focusedSessionID = session.id
                    }
                }
                handled = true
            } else if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { text, _ in
                    guard let text = text as? String else { return }
                    DispatchQueue.main.async { controller.send(text: text) }
                }
                handled = true
            }
        }
        return handled
    }
}

// MARK: - Claude session history

/// Lists the past Claude sessions of the terminal's folder;
/// "Resume" reopens the selected session in the same terminal via `claude --resume`.
struct SessionHistorySheet: View {
    let sessionID: UUID
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [TerminalController.PastSession] = []

    private var theme: ThemeSpec { store.themeSpec }
    private var session: TerminalSessionModel? { store.session(with: sessionID) }
    private var controller: TerminalController? {
        TerminalRegistry.shared.existingController(for: sessionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(Lf("Claude Oturum Geçmişi · %@", session?.name ?? "Terminal"), systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Kapat")) { dismiss() }
            }
            .padding(14)

            Divider()

            if sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(L("Bu klasör için kayıtlı Claude oturumu bulunamadı."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(controller?.currentDirectory ?? session?.workingDirectory ?? "")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(sessions) { past in
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(past.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(past.id.prefix(8))… · \(past.sizeKB) KB")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button(L("Devam Et")) {
                            controller?.resumeClaudeSession(id: past.id)
                            store.focusedSessionID = sessionID
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 440, idealWidth: 490, maxWidth: .infinity,
               minHeight: 340, idealHeight: 410, maxHeight: .infinity)
        .onAppear {
            if let controller, let session {
                sessions = controller.claudePastSessions(
                    cwd: controller.currentDirectory ?? session.workingDirectory
                )
            }
        }
    }
}
