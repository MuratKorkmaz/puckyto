import SwiftUI
import UniformTypeIdentifiers

/// A simple file browser. Rows can be dragged onto a terminal.
struct FilesPanel: View {
    @EnvironmentObject var store: AppStore
    @State private var entries: [FileEntry] = []

    private var theme: ThemeSpec { store.themeSpec }

    struct FileEntry: Identifiable, Hashable {
        var id: URL { url }
        let url: URL
        let isDirectory: Bool
        var name: String { url.lastPathComponent }
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "Files",
                systemImage: "folder.fill",
                trailing: AnyView(
                    HStack(spacing: 8) {
                        Button {
                            goUp()
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.plain)
                        .help(L("Üst klasör"))

                        Button {
                            if let dir = focusedController()?.currentDirectory {
                                store.filesRootPath = dir
                                reload()
                            }
                        } label: {
                            Image(systemName: "terminal")
                        }
                        .buttonStyle(.plain)
                        .help(L("Odaklı terminalin klasörüne git"))
                    }
                    .foregroundStyle(theme.textSecondary)
                )
            )

            Text(store.filesRootPath)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            List(entries) { entry in
                HStack(spacing: 6) {
                    Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                        .font(.system(size: 11))
                        .foregroundStyle(entry.isDirectory ? theme.accent : Color.secondary)
                    Text(entry.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onDrag { NSItemProvider(object: entry.url as NSURL) }
                .onTapGesture(count: 2) {
                    if entry.isDirectory {
                        store.filesRootPath = entry.url.path
                        reload()
                    } else {
                        focusedController()?.paste(path: entry.url.path)
                    }
                }
                .contextMenu {
                    Button(L("Terminale Yolu Yapıştır")) {
                        focusedController()?.paste(path: entry.url.path)
                    }
                    if entry.isDirectory {
                        Button(L("Terminalde cd")) {
                            focusedController()?.sendLine("cd '" + entry.url.path.replacingOccurrences(of: "'", with: "'\\''") + "'")
                        }
                    }
                    Button(L("Finder'da Göster")) {
                        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                    }
                }
            }
            .listStyle(.plain)

            Text(L("💡 Dosyaları terminale sürükleyip bırakabilirsin"))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(8)
        }
        .onAppear(perform: reload)
        .onChange(of: store.filesRootPath) { _, _ in reload() }
    }

    private func reload() {
        let root = URL(fileURLWithPath: store.filesRootPath)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )) ?? []
        entries = urls
            .map { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return FileEntry(url: url, isDirectory: isDir)
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func goUp() {
        let parent = URL(fileURLWithPath: store.filesRootPath).deletingLastPathComponent()
        store.filesRootPath = parent.path
        reload()
    }

    private func focusedController() -> TerminalController? {
        guard let id = store.focusedSessionID else { return nil }
        return TerminalRegistry.shared.existingController(for: id)
    }
}
