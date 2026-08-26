import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    /// Panel width at the moment the resize drag started
    @State private var resizeStartWidth: CGFloat?

    private var theme: ThemeSpec { store.themeSpec }

    private var showsPanel: Bool {
        store.sidebarSection != .neuralMap && !store.panelCollapsed
    }

    var body: some View {
        HStack(spacing: 0) {
            railView
            Divider().overlay(theme.panelBorder)

            if showsPanel && store.panelPin == .left {
                panelContainer
                resizeHandle
            }

            VStack(spacing: 0) {
                topBar
                Divider().overlay(theme.panelBorder)

                switch store.sidebarSection {
                case .neuralMap:
                    NeuralMapView()
                case .logs:
                    BoardReaderView()
                default:
                    TerminalGridView()
                }
            }

            if showsPanel && store.panelPin == .right {
                resizeHandle
                panelContainer
            }
        }
        .background(theme.background)
    }

    // MARK: - Side panel container: content + the pin/hide strip below it

    private var panelContainer: some View {
        VStack(spacing: 0) {
            sidePanel
            Divider().overlay(theme.panelBorder)
            panelControlStrip
        }
        .frame(width: store.sidePanelWidth)
        .background(theme.panel.opacity(0.55))
    }

    private var panelControlStrip: some View {
        HStack(spacing: 10) {
            Button {
                store.panelPin = store.panelPin == .left ? .right : .left
            } label: {
                Image(systemName: store.panelPin == .left
                      ? "rectangle.righthalf.inset.filled"
                      : "rectangle.lefthalf.inset.filled")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .help(store.panelPin == .left ? L("Paneli sağ kenara sabitle") : L("Paneli sol kenara sabitle"))

            Text("\(Int(store.sidePanelWidth)) px")
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                store.panelCollapsed = true
            } label: {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .help(L("Paneli gizle — soldaki bölüm ikonlarına tıklayınca geri açılır"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    /// The thin draggable handle between the panel and the content
    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 7)
            .overlay(Rectangle().fill(theme.panelBorder).frame(width: 1))
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if resizeStartWidth == nil { resizeStartWidth = store.sidePanelWidth }
                        guard let start = resizeStartWidth else { return }
                        let delta = store.panelPin == .left
                            ? value.translation.width
                            : -value.translation.width
                        store.sidePanelWidth = min(max(start + delta, 220), 520)
                    }
                    .onEnded { _ in resizeStartWidth = nil }
            )
    }

    // MARK: - Left icon rail

    private var railView: some View {
        VStack(spacing: 6) {
            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.accent)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(SidebarSection.allCases) { section in
                Button {
                    if store.sidebarSection == section {
                        // Clicking the same section again hides/shows the panel
                        store.panelCollapsed.toggle()
                    } else {
                        store.sidebarSection = section
                        store.panelCollapsed = false
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 15))
                        Text(section.title)
                            .font(.system(size: 7.5, weight: .medium))
                    }
                    .frame(width: 56, height: 46)
                    .background(
                        store.sidebarSection == section ? theme.accent.opacity(0.15) : .clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .foregroundStyle(store.sidebarSection == section ? theme.accent : theme.textSecondary)
                    // Make the whole box clickable (not just the icon/label pixels)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(width: 64)
        .background(theme.panel)
    }

    // MARK: - Side panel by section

    @ViewBuilder
    private var sidePanel: some View {
        switch store.sidebarSection {
        case .workspaces:
            WorkspacesPanel()
        case .sessions:
            SessionsPanel()
        case .wiki:
            WikiPanel()
        case .files:
            FilesPanel()
        case .agents:
            AgentsPanel()
        case .logs:
            LogsPanel()
        case .settings:
            SettingsPanel()
        case .neuralMap:
            EmptyView()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            // Toggle the side panel — an always-visible way to bring it back when hidden
            if store.sidebarSection != .neuralMap {
                Button {
                    store.panelCollapsed.toggle()
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.panelCollapsed ? theme.accent : theme.textSecondary)
                .help(store.panelCollapsed ? L("Paneli göster (⌘\\)") : L("Paneli gizle (⌘\\)"))
            }

            Image(systemName: store.sidebarSection.systemImage)
                .foregroundStyle(theme.accent)
            Text(store.selectedWorkspace?.name ?? "Puckyto")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let ws = store.selectedWorkspace {
                Chip(text: Lf("%@ terminal", ws.sessions.count), systemImage: "terminal", tint: theme.accent)
            }

            Spacer()

            Menu {
                Button(L("🧪 A/B Koşusu...")) { openWindow(id: "dialog-ab") }
                Button(L("🕘 Gönderim Geçmişi...")) { openWindow(id: "dialog-sent") }
                Button(L("📖 Deney Günlüğünü Aç")) { NSWorkspace.shared.open(AppStore.experimentsURL) }
            } label: {
                Image(systemName: "flask.fill")
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(theme.accent)
            .help(L("Prompt mühendisi araçları"))

            Button {
                openWindow(id: "dialog-dispatch")
            } label: {
                Label(L("Görev Gönder"), systemImage: "paperplane.fill")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.bordered)
            .tint(theme.accent)
            .help(L("Tek görevi seçtiğin ajanlara aynı anda gönder (broadcast)"))

            Button {
                store.addSession()
            } label: {
                Label("Terminal", systemImage: "plus")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.panel.opacity(0.7))
        .contentShape(Rectangle())
        // The title bar is hidden, so double-clicking the top bar's empty area zooms the window
        .onTapGesture(count: 2) {
            NSApp.keyWindow?.zoom(nil)
        }
    }

}

// MARK: - Workspaces paneli

struct WorkspacesPanel: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @State private var renamingWorkspaceID: UUID?
    @State private var renameDraft = ""
    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "Workspaces",
                systemImage: "square.stack.3d.up.fill",
                trailing: AnyView(
                    Button {
                        store.addWorkspace()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                )
            )

            List(selection: $store.selectedWorkspaceID) {
                ForEach(store.workspaces) { workspace in
                    HStack {
                        Image(systemName: workspace.icon)
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workspace.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text(Lf("%@ terminal", workspace.sessions.count))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            if let dir = workspace.defaultDirectory {
                                Text("📁 " + (dir as NSString).abbreviatingWithTildeInPath)
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundStyle(theme.accent.opacity(0.75))
                                    .lineLimit(1)
                                    .truncationMode(.head)
                                    .help(Lf("Yeni terminaller bu klasörde açılır: %@", dir))
                            }
                        }
                        Spacer()
                    }
                    .tag(workspace.id)
                    .contextMenu {
                        Button(L("Yeniden Adlandır")) {
                            renameDraft = workspace.name
                            renamingWorkspaceID = workspace.id
                        }
                        Button(L("📁 Varsayılan Klasör Seç...")) { pickDirectory(for: workspace) }
                        if workspace.defaultDirectory != nil {
                            Button(L("Varsayılan Klasörü Kaldır")) {
                                store.setDefaultDirectory(nil, forWorkspace: workspace.id)
                            }
                        }
                        Button(L("Terminal Ekle")) { store.addSession(toWorkspace: workspace.id) }
                        Button(L("📋 Ortak Panoyu Göster")) { openWindow(id: "dialog-board", value: workspace.id) }
                        Button(L("Sil"), role: .destructive) { store.removeWorkspace(workspace.id) }
                    }
                }
            }
            .listStyle(.plain)
            .onChange(of: store.selectedWorkspaceID) { _, _ in
                store.focusedSessionID = store.selectedWorkspace?.sessions.first?.id
                store.maximizedSessionID = nil
                store.scheduleSave()
            }
        }
        .alert(L("Workspace'i Yeniden Adlandır"), isPresented: Binding(
            get: { renamingWorkspaceID != nil },
            set: { if !$0 { renamingWorkspaceID = nil } }
        )) {
            TextField(L("Workspace adı"), text: $renameDraft)
            Button(L("Kaydet")) {
                let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
                if let id = renamingWorkspaceID, !trimmed.isEmpty {
                    store.renameWorkspace(id, to: trimmed)
                }
                renamingWorkspaceID = nil
            }
            Button(L("İptal"), role: .cancel) { renamingWorkspaceID = nil }
        }
    }

    /// Ask for a folder and make it the workspace default — new terminals open there.
    private func pickDirectory(for workspace: WorkspaceModel) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L("Seç")
        panel.message = Lf("%@ için varsayılan klasör — yeni terminaller burada açılır", workspace.name)
        if let dir = workspace.defaultDirectory {
            panel.directoryURL = URL(fileURLWithPath: dir)
        }
        if panel.runModal() == .OK, let url = panel.url {
            store.setDefaultDirectory(url.path, forWorkspace: workspace.id)
        }
    }
}

// MARK: - Sessions paneli

struct SessionsPanel: View {
    @EnvironmentObject var store: AppStore
    @State private var renamingSessionID: UUID?
    @State private var renameDraft = ""
    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "Sessions · \(store.selectedWorkspace?.name ?? "")",
                systemImage: "terminal.fill",
                trailing: AnyView(
                    Button {
                        store.addSession()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                )
            )

            List(selection: $store.focusedSessionID) {
                ForEach(store.selectedWorkspace?.sessions ?? []) { session in
                    SessionRow(session: session, theme: theme)
                        .tag(session.id)
                        .contextMenu {
                            Button(L("Yeniden Adlandır")) {
                                renameDraft = session.name
                                renamingSessionID = session.id
                            }
                            Button(L("Büyüt")) { store.maximizedSessionID = session.id }
                            Button(L("Kapat"), role: .destructive) { store.removeSession(session.id) }
                        }
                }
            }
            .listStyle(.plain)
        }
        .alert(L("Terminali Yeniden Adlandır"), isPresented: Binding(
            get: { renamingSessionID != nil },
            set: { if !$0 { renamingSessionID = nil } }
        )) {
            TextField(L("Terminal adı"), text: $renameDraft)
            Button(L("Kaydet")) {
                let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
                if let id = renamingSessionID, !trimmed.isEmpty {
                    store.binding(forSession: id)?.wrappedValue.name = trimmed
                }
                renamingSessionID = nil
            }
            Button(L("İptal"), role: .cancel) { renamingSessionID = nil }
        }
    }
}

private struct SessionRow: View {
    let session: TerminalSessionModel
    let theme: ThemeSpec

    var body: some View {
        if let controller = TerminalRegistry.shared.existingController(for: session.id) {
            LiveSessionRow(session: session, controller: controller, theme: theme)
        } else {
            HStack {
                StatusDot(active: false, color: theme.accent)
                Text(session.name).font(.system(size: 12))
                Spacer()
            }
        }
    }
}

private struct LiveSessionRow: View {
    let session: TerminalSessionModel
    @ObservedObject var controller: TerminalController
    let theme: ThemeSpec

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(active: controller.isExecuting, color: theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(controller.currentDirectory ?? controller.title)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            if controller.needsAttention {
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                    .help(L("Onay/girdi bekliyor"))
            }
            Text("\(session.agent.emoji)")
            Chip(text: session.agent.provider.tag, tint: session.agent.provider.color)
            Chip(text: "\(controller.hasRealUsage ? "✓" : "≈") \(formatTokens(controller.displayTokens))", tint: theme.accent)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Task dispatcher

/// Sends one task to the terminals of all selected agents at once (broadcast).
struct TaskDispatchSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selected: Set<UUID> = []
    @State private var appendEnter = true

    private var theme: ThemeSpec { store.themeSpec }
    private var sessions: [TerminalSessionModel] { store.selectedWorkspace?.sessions ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(Lf("Görev Gönder · %@", store.selectedWorkspace?.name ?? ""), systemImage: "paperplane.fill")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Kapat")) { dismiss() }
            }

            TextEditor(text: $text)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(height: 110)
                .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.panelBorder, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L("Örn: Durum raporu ver — ne üzerinde çalışıyorsun, engelin var mı?"))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }

            Text(L("Hedef ajanlar"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textSecondary)

            ForEach(sessions) { session in
                Toggle(isOn: Binding(
                    get: { selected.contains(session.id) },
                    set: { on in if on { selected.insert(session.id) } else { selected.remove(session.id) } }
                )) {
                    HStack(spacing: 6) {
                        Text("\(session.agent.emoji) \(session.name)")
                            .font(.system(size: 12))
                        Chip(text: session.agent.provider.tag, tint: session.agent.provider.color)
                        if TerminalRegistry.shared.existingController(for: session.id)?.isAgentSessionOpen != true {
                            Text(L("· ajan kapalı, metin kabuğa gider"))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }

            HStack {
                Toggle(L("Sonuna Enter ekle (gönder)"), isOn: $appendEnter)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                Spacer()
                Button {
                    dispatch()
                } label: {
                    Label(Lf("Gönder (%@)", selected.count), systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 430, idealWidth: 470, maxWidth: .infinity,
               minHeight: 360, maxHeight: .infinity)
        .onAppear {
            selected = Set(sessions.map(\.id))
        }
    }

    private func dispatch() {
        for id in selected {
            if appendEnter {
                store.sendPrompt(text, to: id, source: L("📣 broadcast")) // yaz + Enter
            } else {
                TerminalRegistry.shared.existingController(for: id)?.send(text: text)
            }
        }
        dismiss()
    }
}

// MARK: - Shared board viewer

/// Renders the workspace's BOARD.md file as markdown.
struct BoardSheet: View {
    let workspaceID: UUID
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""

    private var theme: ThemeSpec { store.themeSpec }
    private var workspaceName: String {
        store.workspaces.first { $0.id == workspaceID }?.name ?? "Workspace"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(Lf("Ortak Pano · %@", workspaceName), systemImage: "list.clipboard")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(L("Yenile"))
                Button(L("Kapat")) { dismiss() }
            }
            .padding(14)

            Divider()

            ScrollView {
                MarkdownPreview(text: content, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(theme.background)

            Divider()

            Text(L("Ajanlar bu dosyayı bilir: durumlarını buraya yazar, birbirlerini buradan okur. Koordinatör görev iletimleri de buraya loglanır."))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(10)
        }
        .frame(minWidth: 500, idealWidth: 580, maxWidth: .infinity,
               minHeight: 380, idealHeight: 480, maxHeight: .infinity)
        .onAppear(perform: reload)
    }

    private func reload() {
        let url = store.boardURL(forWorkspace: workspaceID)
        content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
