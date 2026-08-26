import SwiftUI

/// Configures the focused terminal's agent: task description, rule set, persistent memory.
/// "Start Agent" opens the `claude` CLI in the terminal with this configuration.
struct AgentsPanel: View {
    @EnvironmentObject var store: AppStore

    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        if let session = store.focusedSession,
           let binding = store.binding(forSession: session.id) {
            AgentEditor(session: binding)
                .id(session.id) // reload rules/memory when the session changes
        } else {
            VStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text(L("Önce bir terminal seç"))
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct AgentEditor: View {
    @Binding var session: TerminalSessionModel
    @EnvironmentObject var store: AppStore
    @ObservedObject private var cli = CLIAvailability.shared
    @State private var rulesText: String = ""
    @State private var showEmojiPicker = false
    // Persistent memory: MEMORY.md is the single source of truth — what the agent writes shows up here
    @State private var memoryDraft: String = ""
    @State private var memorySaveWork: DispatchWorkItem?
    @FocusState private var memoryFocused: Bool
    private let memoryRefreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var memoryURL: URL { AppStore.memoryURL(forAgent: session.agent.id) }

    private var theme: ThemeSpec { store.themeSpec }
    private var controller: TerminalController? {
        TerminalRegistry.shared.existingController(for: session.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(title: Lf("Agent · %@", session.name), systemImage: "brain.head.profile")
                    .padding(.horizontal, -12)

                if let controller {
                    AgentStatsRow(controller: controller, theme: theme)
                }

                // Templates: apply a ready-made configuration, or turn this agent into a template
                HStack(spacing: 8) {
                    Menu {
                        ForEach(store.agentTemplates) { template in
                            Button("\(template.emoji) \(template.title)") { apply(template) }
                        }
                    } label: {
                        Label(L("Şablondan Uygula"), systemImage: "square.on.square")
                            .font(.system(size: 10.5))
                    }

                    Spacer()

                    Button {
                        saveAsTemplate()
                    } label: {
                        Label(L("Şablon Kaydet"), systemImage: "square.and.arrow.down")
                            .font(.system(size: 10.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .help(L("Bu ajanın ayarlarını şablon olarak kaydet (Settings'ten yönetilir)"))
                }

                HStack(spacing: 8) {
                    // Icon: clicking opens the emoji picker
                    Button {
                        showEmojiPicker.toggle()
                    } label: {
                        Text(session.agent.emoji.isEmpty ? "🤖" : session.agent.emoji)
                            .font(.system(size: 17))
                            .frame(width: 40, height: 24)
                            .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.panelBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(L("Ajan ikonunu seç"))
                    .popover(isPresented: $showEmojiPicker, arrowEdge: .bottom) {
                        EmojiPickerView(selected: $session.agent.emoji)
                    }

                    TextField(L("Ad (terminal = ajan)"), text: Binding(
                        get: { session.name },
                        set: { session.name = $0; session.agent.name = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                sectionLabel(L("AI Sağlayıcı"), icon: "cpu")
                Picker("", selection: $session.agent.provider) {
                    ForEach(AgentProvider.allCases) { provider in
                        // CLIs that are not installed are marked with ⚠️ in the picker
                        Text(provider.displayName + (cli.isAvailable(provider) == false ? " ⚠️" : ""))
                            .tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 6) {
                    Chip(text: session.agent.provider.tag, tint: session.agent.provider.color)
                    Text("CLI: `\(session.agent.provider.executable)`")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if cli.isAvailable(session.agent.provider) == false {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 11))
                        Text(Lf("`%@` kurulu değil — PATH'te bulunamadı. Ajan başlatılırsa terminalde \"command not found\" görürsün.", session.agent.provider.executable))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L("Yeniden Tara")) { cli.refresh() }
                            .controlSize(.mini)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionLabel("Model", icon: "cpu.fill")
                        Picker("", selection: $session.agent.model) {
                            Text(L("Varsayılan")).tag("")
                            // The list comes from the catalog in Settings (the user can edit it)
                            ForEach(store.models(for: session.agent.provider)) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }

                    if !session.agent.provider.efforts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            sectionLabel("Effort", icon: "gauge.with.needle")
                            Picker("", selection: $session.agent.effort) {
                                Text(L("Varsayılan")).tag("")
                                ForEach(session.agent.provider.efforts, id: \.self) { effort in
                                    Text(effort).tag(effort)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .onChange(of: session.agent.provider) { _, newProvider in
                    // When the provider changes, clear the model/effort choice of the old provider
                    if !store.models(for: newProvider).contains(where: { $0.value == session.agent.model }) {
                        session.agent.model = ""
                    }
                    if !newProvider.efforts.contains(session.agent.effort) { session.agent.effort = "" }
                }

                sectionLabel(L("Görev Tanımı"), icon: "target")
                TextEditor(text: $session.agent.task)
                    .font(.system(size: 11))
                    .scrollContentBackground(.hidden)
                    .frame(height: 70)
                    .padding(4)
                    .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

                sectionLabel(L("Kurallar (her satır bir kural)"), icon: "list.bullet.rectangle")
                TextEditor(text: $rulesText)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(height: 80)
                    .padding(4)
                    .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .topLeading) {
                        if rulesText.isEmpty {
                            Text(L("Örn:\nHer zaman Türkçe yanıt ver\nDosya silmeden önce onay iste\nHer değişiklikten sonra testleri çalıştır"))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 9)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: rulesText) { _, newValue in
                        session.agent.rules = newValue
                            .split(separator: "\n")
                            .map(String.init)
                    }

                HStack {
                    sectionLabel(L("Kalıcı Hafıza (MEMORY.md)"), icon: "memorychip")
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(theme.accent).frame(width: 5, height: 5)
                        Text(L("canlı — dosyadan"))
                            .font(.system(size: 8.5))
                            .foregroundStyle(.tertiary)
                    }
                    Button {
                        reloadMemory()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .help(L("Dosyadan şimdi yenile"))
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([memoryURL])
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .help(L("MEMORY.md'yi Finder'da göster"))
                }
                TextEditor(text: $memoryDraft)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused($memoryFocused)
                    .frame(height: 110)
                    .padding(4)
                    .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .onChange(of: memoryDraft) { _, _ in scheduleMemorySave() }
                Text(L("Ajan bu dosyayı kendisi de günceller; sen yazmıyorken 3 sn'de bir diskten tazelenir."))
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)

                if session.agent.provider == .claude {
                    sectionLabel(L("İzin Modu"), icon: "checkmark.shield")
                    Picker("", selection: $session.agent.permissionMode) {
                        Text(L("Sor (varsayılan)")).tag("")
                        Text(L("Plan — önce plan sunar")).tag("plan")
                        Text(L("Düzenlemeleri otomatik onayla")).tag("acceptEdits")
                        Text(L("⚡ Tam otonom (izin sormaz)")).tag("bypass")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if session.agent.permissionMode == "bypass" {
                        Text(L("⚠️ Tam otonom mod tüm izin kontrollerini atlar (`--dangerously-skip-permissions`). Yalnızca güvendiğin görevlerde ve tercihen izole worktree'de kullan."))
                            .font(.system(size: 9))
                            .foregroundStyle(.orange.opacity(0.9))
                    }
                }

                Toggle(L("Terminal açılınca ajanı otomatik başlat"), isOn: $session.agent.autoStart)
                    .font(.system(size: 11))

                Toggle(isOn: $session.agent.coordinator) {
                    HStack(spacing: 4) {
                        Text(L("🎯 Koordinatör ajan"))
                            .font(.system(size: 11, weight: .semibold))
                        Text(L("— diğer ajanlara görev atayabilir"))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .help(L("Başlatılırken ajana görev kuyruğu öğretilir: kuyruğa yazdığı JSON görevleri uygulama hedef terminallere iletir."))

                Button {
                    startAgentWithContext()
                } label: {
                    Label(
                        (controller?.isAgentSessionOpen == true ? L("Ajanı Yeniden Başlat") : L("Ajanı Başlat"))
                            + " (\(session.agent.provider.executable))",
                        systemImage: controller?.isAgentSessionOpen == true ? "arrow.clockwise" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(session.agent.provider.color)
                .disabled(controller == nil)

                if controller?.isAgentSessionOpen == true {
                    Text(L("⚠️ Terminalde açık bir AI oturumu var. Model/effort/görev değişiklikleri çalışan oturuma yansımaz — \"Yeniden Başlat\" mevcut oturumu kapatıp (çift Ctrl+C) yeni ayarlarla açar."))
                        .font(.system(size: 9))
                        .foregroundStyle(.orange.opacity(0.9))
                }

                Text(session.agent.provider.launchCommand(
                    prompt: L("<görev + kurallar + hafıza>"),
                    model: session.agent.model,
                    effort: session.agent.effort
                ))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.accent.opacity(0.8))
                .textSelection(.enabled)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

                Text(Lf("Ajan, terminalde `%@` CLI olarak başlatılır. Görev + kurallar başlangıç prompt'una eklenir; hafıza dosyası ajanla paylaşılır. Seçili CLI'nin sistemde kurulu olması gerekir.", session.agent.provider.executable))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .onAppear {
            rulesText = session.agent.rules.joined(separator: "\n")
            reloadMemory()
        }
        .onDisappear { saveMemoryNow() }
        .onReceive(memoryRefreshTimer) { _ in
            // Do not disturb the caret while the user types; reflect the agent's edits otherwise
            if !memoryFocused { reloadMemory(onlyIfChanged: true) }
        }
    }

    /// Read MEMORY.md from disk (show the seed text from state when the file is missing)
    private func reloadMemory(onlyIfChanged: Bool = false) {
        let fileText = (try? String(contentsOf: memoryURL, encoding: .utf8)) ?? session.agent.memory
        if !onlyIfChanged || fileText != memoryDraft {
            memoryDraft = fileText
        }
    }

    private func scheduleMemorySave() {
        memorySaveWork?.cancel()
        let work = DispatchWorkItem { saveMemoryNow() }
        memorySaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    /// Write the editor text to the file and mirror it into state
    private func saveMemoryNow() {
        try? memoryDraft.write(to: memoryURL, atomically: true, encoding: .utf8)
        if session.agent.memory != memoryDraft {
            session.agent.memory = memoryDraft
        }
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.textSecondary)
    }

    /// Starts the agent with the board context (and the queue for coordinators).
    private func startAgentWithContext() {
        let workspaceID = store.workspaceID(containingSession: session.id)
        var agent = session.agent
        agent.name = session.name // single identity: terminal name = agent name
        controller?.startAgent(
            agent,
            boardURL: store.boardURL(forSession: session.id),
            queueDir: session.agent.coordinator && workspaceID != nil
                ? store.queueDirectory(forWorkspace: workspaceID!) : nil,
            roster: store.workspaces.first { $0.id == workspaceID }?.sessions
                .filter { $0.id != session.id }
                .map(\.name) ?? []
        )
    }

    private func apply(_ template: AgentTemplate) {
        session.name = template.title
        session.agent.name = template.title
        session.agent.emoji = template.emoji
        session.agent.provider = template.provider
        session.agent.model = template.model
        session.agent.effort = template.effort
        session.agent.task = template.task
        session.agent.rules = template.rules
        rulesText = template.rules.joined(separator: "\n")
    }

    private func saveAsTemplate() {
        store.agentTemplates.append(AgentTemplate(
            title: session.name,
            emoji: session.agent.emoji,
            provider: session.agent.provider,
            model: session.agent.model,
            effort: session.agent.effort,
            task: session.agent.task,
            rules: session.agent.rules
        ))
    }
}

/// A grid emoji picker — the agent icon is chosen only from here.
struct EmojiPickerView: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    private static let emojis: [String] = [
        "🤖", "🧠", "👾", "🦾", "⚙️", "🛠", "🔧", "🧰",
        "💻", "🖥", "⌨️", "📟", "🕹", "💾", "📡", "🛰",
        "🚀", "🛸", "🧭", "🔭", "🔬", "🧪", "🧬", "⚗️",
        "📚", "📖", "📝", "✏️", "📋", "🗂", "📁", "🔍",
        "🛡", "⚔️", "🗡", "🏹", "🎯", "🧩", "♟", "🎲",
        "🕵️", "🥷", "🧙", "👮", "🧑‍🚀", "🧑‍💻", "🦸", "🧛",
        "🦉", "🦅", "🦊", "🐺", "🐉", "🦖", "🐙", "🐝",
        "⚡️", "🔥", "❄️", "🌊", "🌪", "☄️", "🌟", "✨",
        "💡", "🔦", "🔋", "🔌", "🧿", "⚛️", "♻️", "🌀",
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8), spacing: 4) {
                ForEach(Self.emojis, id: \.self) { emoji in
                    Button {
                        selected = emoji
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 17))
                            .frame(width: 28, height: 28)
                            .background(
                                selected == emoji ? Color.accentColor.opacity(0.28) : .clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .frame(width: 296, height: 250)
    }
}

/// Live agent statistics: tokens, memory, activity
struct AgentStatsRow: View {
    @ObservedObject var controller: TerminalController
    let theme: ThemeSpec

    var body: some View {
        HStack(spacing: 8) {
            statBox(title: controller.hasRealUsage ? L("Token (gerçek)") : L("Token (tahmin)"), value: formatTokens(controller.displayTokens), icon: "circle.hexagongrid.fill")
            statBox(title: L("Bellek"), value: formatBytes(controller.memoryBytes), icon: "memorychip.fill")
            statBox(
                title: L("Durum"),
                value: controller.agentRunning ? L("Aktif") : (controller.running ? L("Hazır") : L("Kapalı")),
                icon: "bolt.fill"
            )
        }
    }

    private func statBox(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(theme.accent)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
