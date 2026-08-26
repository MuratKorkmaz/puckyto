import SwiftUI

// MARK: - Full system prompt preview

/// The exact system prompt to be injected into the agent, plus the launch command.
struct PromptPreviewSheet: View {
    let sessionID: UUID
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var command = ""

    private var theme: ThemeSpec { store.themeSpec }
    private var session: TerminalSessionModel? { store.session(with: sessionID) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(Lf("Sistem Promptu · %@", session?.name ?? ""), systemImage: "text.magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Kapat")) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(L("Enjekte edilen sistem promptu"), copyText: prompt)
                    Text(prompt)
                        .font(.system(size: 11.5, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))

                    sectionHeader(L("Tam başlatma komutu"), copyText: command)
                    Text(command)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(theme.accent.opacity(0.9))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))

                    Text(L("Bu, \"Ajanı Başlat\" dediğinde çalışacak içeriğin birebir kopyası — görev, kurallar, hafıza/wiki/pano yolları ve (koordinatörse) kuyruk talimatı dahil."))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }
        }
        .frame(minWidth: 560, idealWidth: 640, maxWidth: .infinity,
               minHeight: 400, idealHeight: 480, maxHeight: .infinity)
        .onAppear(perform: rebuild)
    }

    private func sectionHeader(_ title: String, copyText: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(copyText, forType: .string)
            } label: {
                Label(L("Kopyala"), systemImage: "doc.on.doc")
                    .font(.system(size: 10))
            }
            .controlSize(.small)
        }
    }

    private func rebuild() {
        guard let session,
              let controller = TerminalRegistry.shared.existingController(for: sessionID) else { return }
        var agent = session.agent
        agent.name = session.name
        let workspaceID = store.workspaceID(containingSession: sessionID)
        prompt = controller.buildAgentPrompt(
            agent,
            boardURL: store.boardURL(forSession: sessionID),
            queueDir: agent.coordinator && workspaceID != nil
                ? store.queueDirectory(forWorkspace: workspaceID!) : nil,
            roster: store.workspaces.first { $0.id == workspaceID }?.sessions
                .filter { $0.id != sessionID }.map(\.name) ?? []
        )
        command = agent.provider.launchCommand(
            prompt: prompt, model: agent.model, effort: agent.effort,
            permissionMode: agent.permissionMode
        )
    }
}

// MARK: - Send history

struct SentHistorySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var theme: ThemeSpec { store.themeSpec }

    private var filtered: [SentPrompt] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return store.sentHistory }
        return store.sentHistory.filter {
            $0.text.localizedCaseInsensitiveContains(query) ||
            $0.sessionName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L("Gönderim Geçmişi"), systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Temizle")) { store.sentHistory.removeAll(); store.scheduleSave() }
                    .controlSize(.small)
                Button(L("Kapat")) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            TextField(L("Ara: metin ya da ajan adı..."), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text(store.sentHistory.isEmpty
                         ? L("Henüz gönderim yok — ⚡ hızlı komutlar, broadcast ve kuyruk buraya kaydedilir.")
                         : L("Aramayla eşleşen kayıt yok."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.date.formatted(date: .abbreviated, time: .standard))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Chip(text: entry.source, tint: theme.accent)
                            Chip(text: entry.sessionName, tint: .secondary)
                            Spacer()
                            Button(L("Kopyala")) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.text, forType: .string)
                            }
                            .controlSize(.mini)
                            Button(L("Tekrar Gönder")) {
                                store.sendPrompt(entry.text, to: entry.sessionID, source: L("↻ tekrar"))
                            }
                            .controlSize(.mini)
                            .disabled(store.session(with: entry.sessionID) == nil)
                        }
                        Text(entry.text)
                            .font(.system(size: 11))
                            .lineLimit(3)
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 560, idealWidth: 620, maxWidth: .infinity,
               minHeight: 400, idealHeight: 480, maxHeight: .infinity)
    }
}

// MARK: - CLAUDE.md editor

/// Edits the CLAUDE.md in the terminal's folder (creating it when missing).
struct ClaudeMdSheet: View {
    let sessionID: UUID
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var saveWork: DispatchWorkItem?
    @State private var exists = false

    private var theme: ThemeSpec { store.themeSpec }
    private var session: TerminalSessionModel? { store.session(with: sessionID) }

    private var fileURL: URL? {
        guard let session else { return nil }
        let cwd = TerminalRegistry.shared.existingController(for: sessionID)?.currentDirectory
            ?? session.workingDirectory
        return URL(fileURLWithPath: cwd).appendingPathComponent("CLAUDE.md")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("CLAUDE.md · \(session?.name ?? "")", systemImage: "doc.badge.gearshape")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    if let url = fileURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .help(L("Finder'da göster"))
                Button(L("Kapat")) { saveNow(); dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            Text(fileURL?.path ?? "")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(theme.background)
                .onChange(of: text) { _, _ in scheduleSave() }

            Divider()

            Text(exists
                 ? L("Değişiklikler otomatik kaydedilir. CLAUDE.md, o klasörde çalışan her claude oturumuna proje talimatı olarak yüklenir — etkisi için ajanı yeniden başlat.")
                 : L("Bu klasörde CLAUDE.md yok — yazmaya başladığında oluşturulur."))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(10)
        }
        .frame(minWidth: 540, idealWidth: 620, maxWidth: .infinity,
               minHeight: 420, idealHeight: 500, maxHeight: .infinity)
        .onAppear(perform: load)
        .onDisappear(perform: saveNow)
    }

    private func load() {
        guard let url = fileURL else { return }
        exists = FileManager.default.fileExists(atPath: url.path)
        text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func saveNow() {
        guard let url = fileURL else { return }
        guard !text.isEmpty || exists else { return } // do not create the file while it is empty
        try? text.write(to: url, atomically: true, encoding: .utf8)
        exists = true
    }
}

// MARK: - A/B comparison run

/// Sends the same task to 2-3 Claude agents in parallel and shows the replies side by side;
/// with 👍/👎 + a note it is recorded in the experiment log (experiments.md).
struct ABRunSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var task = ""
    @State private var selected: [UUID] = []
    @State private var running = false
    @State private var baseline: [UUID: String] = [:]
    @State private var tokensStart: [UUID: Int] = [:]
    @State private var results: [UUID: String] = [:]
    @State private var verdicts: [UUID: Bool] = [:]
    @State private var note = ""

    private var theme: ThemeSpec { store.themeSpec }
    private let pollTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    /// Claude-agent sessions only — reply capture works off the session file
    private var candidates: [TerminalSessionModel] {
        store.workspaces.flatMap(\.sessions).filter { $0.agent.provider == .claude }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L("A/B Koşusu"), systemImage: "flask.fill")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    NSWorkspace.shared.open(AppStore.experimentsURL)
                } label: {
                    Label(L("Günlüğü Aç"), systemImage: "book")
                        .font(.system(size: 10.5))
                }
                .controlSize(.small)
                Button(L("Kapat")) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("GÖREV"))
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.tertiary)
                    TextEditor(text: $task)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .frame(height: 70)
                        .padding(6)
                        .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.panelBorder, lineWidth: 1))

                    Text(L("VARYANTLAR (2-3 Claude ajanı seç — model/effort/prompt farkını ajanlarda ayarla)"))
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.tertiary)

                    ForEach(candidates) { session in
                        Toggle(isOn: Binding(
                            get: { selected.contains(session.id) },
                            set: { on in
                                if on { if selected.count < 3 { selected.append(session.id) } }
                                else { selected.removeAll { $0 == session.id } }
                            }
                        )) {
                            HStack(spacing: 6) {
                                Text("\(session.agent.emoji) \(session.name)")
                                    .font(.system(size: 12))
                                Chip(text: session.agent.model.isEmpty ? L("model: varsayılan") : session.agent.model,
                                     tint: theme.accent)
                                if !session.agent.effort.isEmpty {
                                    Chip(text: session.agent.effort, tint: .secondary)
                                }
                                if TerminalRegistry.shared.existingController(for: session.id)?.isAgentSessionOpen != true {
                                    Text(L("· ajan kapalı!"))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                        .disabled(running)
                    }

                    Button {
                        startRun()
                    } label: {
                        Label(running ? L("Koşu sürüyor...") : Lf("Koşuyu Başlat (%@ varyant)", selected.count),
                              systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .disabled(running || selected.count < 2
                              || task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if running || !results.isEmpty {
                        resultsGrid
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 720, idealWidth: 860, maxWidth: .infinity,
               minHeight: 480, idealHeight: 560, maxHeight: .infinity)
        .onReceive(pollTimer) { _ in poll() }
    }

    // MARK: Results

    private var resultsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(theme.panelBorder)
            Text(L("SONUÇLAR"))
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.tertiary)

            HStack(alignment: .top, spacing: 10) {
                ForEach(selected, id: \.self) { id in
                    resultColumn(id)
                }
            }

            HStack(spacing: 8) {
                TextField(L("Deney notu (hangisi neden iyi/kötü?)"), text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                Button {
                    saveExperiment()
                } label: {
                    Label(L("Günlüğe Kaydet"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)
                .disabled(results.isEmpty)
            }
        }
    }

    private func resultColumn(_ id: UUID) -> some View {
        let session = store.session(with: id)
        let controller = TerminalRegistry.shared.existingController(for: id)
        let reply = results[id]
        let tokensUsed = (controller.map { $0.realInputTokens + $0.realOutputTokens } ?? 0)
            - (tokensStart[id] ?? 0)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text("\(session?.agent.emoji ?? "") \(session?.name ?? "?")")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                if reply == nil {
                    ProgressView().controlSize(.small)
                } else {
                    Chip(text: "\(formatTokens(max(0, tokensUsed))) tok", tint: theme.accent)
                }
            }

            if let reply {
                ScrollView {
                    MarkdownPreview(text: reply, theme: theme)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .frame(minHeight: 140, maxHeight: 260)
                .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 8) {
                    Button {
                        verdicts[id] = true
                    } label: {
                        Text("👍").opacity(verdicts[id] == true ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    Button {
                        verdicts[id] = false
                    } label: {
                        Text("👎").opacity(verdicts[id] == false ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(L("Kopyala")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(reply, forType: .string)
                    }
                    .controlSize(.mini)
                }
            } else {
                Text(running ? L("Yanıt bekleniyor...") : "—")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(theme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Flow

    private func startRun() {
        results.removeAll()
        verdicts.removeAll()
        for id in selected {
            let controller = TerminalRegistry.shared.existingController(for: id)
            baseline[id] = controller?.lastAssistantMessage()?.id ?? ""
            tokensStart[id] = (controller?.realInputTokens ?? 0) + (controller?.realOutputTokens ?? 0)
            store.sendPrompt(task, to: id, source: L("🧪 a/b"))
        }
        running = true
    }

    private func poll() {
        guard running else { return }
        for id in selected where results[id] == nil {
            guard let controller = TerminalRegistry.shared.existingController(for: id),
                  controller.isAgentSessionOpen, !controller.isExecuting,
                  let message = controller.lastAssistantMessage(),
                  message.id != baseline[id] else { continue }
            results[id] = message.text
        }
        if results.count == selected.count { running = false }
    }

    private func saveExperiment() {
        let stamp = Date().formatted(date: .abbreviated, time: .standard)
        var md = Lf("\n---\n\n## 🧪 %@\n\n**Görev:** %@\n\n", stamp, task)
        for id in selected {
            guard let session = store.session(with: id) else { continue }
            let verdict = verdicts[id] == true ? "👍" : (verdicts[id] == false ? "👎" : "—")
            let model = session.agent.model.isEmpty ? L("varsayılan") : session.agent.model
            let effort = session.agent.effort.isEmpty ? L("varsayılan") : session.agent.effort
            md += "### \(verdict) \(session.name) (\(model) · \(effort))\n\n"
            md += (results[id].map { $0.prefix(1500) + ($0.count > 1500 ? L("\n\n*(kırpıldı)*") : "") } ?? L("yanıt alınamadı"))
            md += "\n\n"
        }
        if !note.trimmingCharacters(in: .whitespaces).isEmpty {
            md += Lf("**Not:** %@\n", note)
        }
        store.appendExperiment(md)
        note = ""
    }
}
