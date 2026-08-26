import SwiftUI

// MARK: - Logs side panel: workspace selection + name/folder editing

/// Side panel of the Logs section. Pick a workspace and edit its name and default
/// folder here; its shared board is shown live in the reader on the right.
struct LogsPanel: View {
    @EnvironmentObject var store: AppStore
    @State private var nameDraft = ""

    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: L("Logs · Ortak Pano"), systemImage: "list.clipboard.fill")

            List(selection: $store.selectedWorkspaceID) {
                ForEach(store.workspaces) { workspace in
                    HStack(spacing: 6) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.accent)
                        Text(workspace.name)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(workspace.sessions.count)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .tag(workspace.id)
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 160)

            Divider().overlay(theme.panelBorder)

            if let workspace = store.selectedWorkspace {
                workspaceSettings(workspace)
            }

            Spacer(minLength: 0)
        }
        .onAppear { nameDraft = store.selectedWorkspace?.name ?? "" }
        .onChange(of: store.selectedWorkspaceID) { _, _ in
            nameDraft = store.selectedWorkspace?.name ?? ""
        }
    }

    /// Settings of the selected workspace: name, default folder, board actions
    private func workspaceSettings(_ workspace: WorkspaceModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(L("Workspace Adı"), icon: "pencil")
                TextField("Ad", text: $nameDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { store.renameWorkspace(workspace.id, to: trimmed) }
                    }

                sectionLabel(L("Varsayılan Klasör"), icon: "folder")
                Text(workspace.defaultDirectory.map { ($0 as NSString).abbreviatingWithTildeInPath }
                     ?? L("Atanmadı — yeni terminaller ev dizininde açılır"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(workspace.defaultDirectory == nil ? Color.secondary.opacity(0.6) : theme.accent)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 8) {
                    Button(L("Değiştir...")) { pickDirectory(for: workspace) }
                        .controlSize(.small)
                    if workspace.defaultDirectory != nil {
                        Button(L("Kaldır")) { store.setDefaultDirectory(nil, forWorkspace: workspace.id) }
                            .controlSize(.small)
                    }
                }

                Divider().overlay(theme.panelBorder)

                sectionLabel(L("Ortak Pano"), icon: "list.clipboard")
                Text(L("Ajanlar durumlarını ve kararlarını panoya yazar; koordinatör görev iletimleri de buraya loglanır. Sağdaki okuyucu 2 sn'de bir tazelenir."))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([store.boardURL(forWorkspace: workspace.id)])
                    } label: {
                        Label(L("Finder'da Göster"), systemImage: "folder")
                            .font(.system(size: 10.5))
                    }
                    .controlSize(.small)

                    Button(role: .destructive) {
                        store.resetBoard(forWorkspace: workspace.id)
                    } label: {
                        Label(L("Panoyu Sıfırla"), systemImage: "trash")
                            .font(.system(size: 10.5))
                    }
                    .controlSize(.small)
                    .help(L("Pano içeriğini temizler (geri alınamaz)"))
                }
            }
            .padding(12)
        }
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.textSecondary)
    }

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

// MARK: - Board reader: full width, live tail

/// Shows the selected workspace's shared board in place of the terminal grid, wide and
/// readable. Refreshes from disk every 2s; with follow enabled it scrolls to the end
/// as new content arrives (like tailing a log).
struct BoardReaderView: View {
    @EnvironmentObject var store: AppStore
    @State private var content = ""
    @State private var follow = true
    @State private var lastLoadedWorkspaceID: UUID?

    private var theme: ThemeSpec { store.themeSpec }
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.panelBorder)

            if store.selectedWorkspace == nil {
                VStack(spacing: 8) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text(L("Soldan bir workspace seç"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        MarkdownPreview(text: content, theme: theme)
                            .frame(maxWidth: 860, alignment: .leading)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 20)

                        // Anchor for the live tail
                        Color.clear.frame(height: 1).id("board-bottom")
                    }
                    .onChange(of: content) { _, _ in
                        if follow {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("board-bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .background(theme.background)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: store.selectedWorkspaceID) { _, _ in reload() }
        .onReceive(refreshTimer) { _ in reload() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.clipboard.fill")
                .foregroundStyle(theme.accent)
            Text(Lf("Ortak Pano · %@", store.selectedWorkspace?.name ?? "—"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            // Live indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 6, height: 6)
                Text(L("canlı — 2 sn'de bir tazelenir"))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle(isOn: $follow) {
                Label(L("Sona takıl"), systemImage: "arrow.down.to.line")
                    .font(.system(size: 10.5))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help(L("Açıkken yeni log geldikçe otomatik en alta kayar"))

            Button {
                reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .help(L("Şimdi yenile"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.panel.opacity(0.6))
    }

    private func reload() {
        guard let workspace = store.selectedWorkspace else { return }
        let url = store.boardURL(forWorkspace: workspace.id)
        let fresh = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        // Do not reset the tail on a workspace change; skip re-rendering identical content
        if fresh != content || lastLoadedWorkspaceID != workspace.id {
            content = fresh
            lastLoadedWorkspaceID = workspace.id
        }
    }
}
