import SwiftUI
import UniformTypeIdentifiers

/// The wiki panel. With the pickers at the top:
/// - "Workspace": changes which workspace is shown in the terminal grid on the right,
/// - "Wiki Source": picks whose wiki is listed (independent of the workspace).
/// This way a note from any wiki can be dropped onto any agent's terminal.
struct WikiPanel: View {
    @EnvironmentObject var store: AppStore
    /// The terminal whose wiki the user picked; nil falls back to the focused terminal
    @State private var wikiSessionID: UUID?

    private var theme: ThemeSpec { store.themeSpec }

    /// The effective wiki source: the user's pick (while it still exists), else the focused terminal
    private var currentWikiSessionID: UUID? {
        if let id = wikiSessionID, store.session(with: id) != nil { return id }
        return store.focusedSession?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Wiki", systemImage: "book.pages.fill")
            pickers
            Divider().overlay(theme.panelBorder)

            if let id = currentWikiSessionID, let session = store.session(with: id) {
                WikiNotesView(sessionID: id, sessionName: session.name)
                    .id(id) // rebind the wiki store when the source changes
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(L("Wiki için bir terminal seç"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if wikiSessionID == nil { wikiSessionID = store.focusedSessionID }
        }
    }

    private var pickers: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The workspace shown in the grid on the right, so the target agent's terminal is visible
            VStack(alignment: .leading, spacing: 2) {
                Label(L("Workspace (sürükleme hedefi)"), systemImage: "square.stack.3d.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: workspaceBinding) {
                    ForEach(store.workspaces) { workspace in
                        Text(Lf("%@ · %@ terminal", workspace.name, workspace.sessions.count))
                            .tag(Optional(workspace.id))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Whose wiki to display (selectable across all workspaces)
            VStack(alignment: .leading, spacing: 2) {
                Label(L("Wiki kaynağı"), systemImage: "book.pages")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $wikiSessionID) {
                    ForEach(store.workspaces) { workspace in
                        Section(workspace.name) {
                            ForEach(workspace.sessions) { session in
                                Text("\(session.agent.emoji) \(session.name)")
                                    .tag(Optional(session.id))
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Text(L("💡 Notu sağdaki herhangi bir terminale sürükleyip bırak"))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    /// Workspace selection: changes the grid but leaves the wiki source alone.
    private var workspaceBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedWorkspace?.id },
            set: { newID in
                guard let newID, newID != store.selectedWorkspaceID else { return }
                store.selectedWorkspaceID = newID
                store.focusedSessionID = store.selectedWorkspace?.sessions.first?.id
                store.maximizedSessionID = nil
                store.scheduleSave()
            }
        )
    }
}

/// A single terminal's wiki: note list + markdown editor/preview.
/// Notes can be dragged onto a terminal (the file path is pasted).
struct WikiNotesView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var wiki: WikiStore
    @State private var newNoteTitle = ""
    @State private var showPreview = false
    @FocusState private var editorFocused: Bool

    private let sessionID: UUID
    private let sessionName: String

    init(sessionID: UUID, sessionName: String) {
        self.sessionID = sessionID
        self.sessionName = sessionName
        _wiki = StateObject(wrappedValue: WikiStore.store(for: sessionID))
    }

    private var theme: ThemeSpec { store.themeSpec }

    private var agentEmoji: String {
        store.session(with: sessionID)?.agent.emoji ?? "🤖"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Say clearly whose notebook this is
                Text(Lf("📖 %@ %@ wiki'si", agentEmoji, sessionName))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.accent)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            HStack(spacing: 6) {
                TextField(L("Yeni not başlığı"), text: $newNoteTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onSubmit(createNote)
                Button(action: createNote) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            List(selection: Binding(
                get: { wiki.selectedNoteURL },
                set: { wiki.select($0) }
            )) {
                ForEach(wiki.notes) { note in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(note.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Text(note.modified, style: .relative)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .tag(note.url)
                    .onDrag { NSItemProvider(object: note.url as NSURL) }
                    .contextMenu {
                        Button(L("Terminale Yolu Yapıştır")) {
                            focusedController()?.paste(path: note.url.path)
                        }
                        Button(L("İçeriği Terminale Gönder")) {
                            if let content = try? String(contentsOf: note.url, encoding: .utf8) {
                                focusedController()?.send(text: content)
                            }
                        }
                        Divider()
                        Button(L("Sil"), role: .destructive) { wiki.deleteNote(note.url) }
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 170)

            Divider().overlay(theme.panelBorder)

            HStack {
                Text(wiki.selectedNoteURL?.deletingPathExtension().lastPathComponent ?? L("Not seçilmedi"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Picker("", selection: $showPreview) {
                    Image(systemName: "pencil").tag(false)
                    Image(systemName: "eye").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 76)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if wiki.selectedNoteURL == nil {
                // Do not show an editor without a note: anything typed could not be saved
                VStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 26))
                        .foregroundStyle(.tertiary)
                    Text(L("Önce yukarıdan bir başlık yazıp ⏎ (veya +) ile not oluştur,\nsonra içeriği buraya yazabilirsin."))
                        .font(.system(size: 10))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showPreview {
                ScrollView {
                    MarkdownPreview(text: wiki.draft, theme: theme)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            } else {
                TextEditor(text: $wiki.draft)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    .padding(6)
                    .frame(minHeight: 140, maxHeight: .infinity)
                    .background(theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.panelBorder, lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if wiki.draft.isEmpty {
                            Text(L("Notunu buraya yaz..."))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 12)
                                .padding(.leading, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(8)
                    .onChange(of: wiki.draft) { _, _ in debounceSave() }
            }
        }
        .onDisappear { wiki.saveDraft() }
        .onChange(of: wiki.selectedNoteURL) { _, newValue in
            // Move the caret straight into the editor once a note is selected/created
            if newValue != nil {
                showPreview = false
                DispatchQueue.main.async { editorFocused = true }
            }
        }
    }

    private func createNote() {
        let title = newNoteTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        wiki.createNote(titled: title)
        newNoteTitle = ""
    }

    private func focusedController() -> TerminalController? {
        guard let id = store.focusedSessionID else { return nil }
        return TerminalRegistry.shared.existingController(for: id)
    }

    @State private var saveWork: DispatchWorkItem?
    private func debounceSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { wiki.saveDraft() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
}

// MARK: - Markdown preview

/// Block-level markdown rendering for wiki notes: headings, lists, task boxes, quotes,
/// code blocks and rules. Inline formatting (bold/italic/`code`) is handled by
/// AttributedString's markdown parser.
struct MarkdownPreview: View {
    let text: String
    let theme: ThemeSpec

    private enum Block {
        case heading(level: Int, text: String)
        case bullet(String)
        case numbered(number: String, text: String)
        case task(done: Bool, text: String)
        case quote(String)
        case code([String])
        case divider
        case paragraph(String)
        case blank
    }

    var body: some View {
        let blocks = Self.parse(text)
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
        .textSelection(.enabled)
    }

    // MARK: Parsing

    private static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var codeLines: [String]? = nil

        for rawLine in text.components(separatedBy: "\n") {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code fences
            if trimmed.hasPrefix("```") {
                if let lines = codeLines {
                    blocks.append(.code(lines))
                    codeLines = nil
                } else {
                    codeLines = []
                }
                continue
            }
            if codeLines != nil {
                codeLines?.append(line)
                continue
            }

            if trimmed.isEmpty {
                blocks.append(.blank)
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.divider)
            } else if let heading = parseHeading(trimmed) {
                blocks.append(heading)
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                blocks.append(.task(done: true, text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix("- [ ] ") {
                blocks.append(.task(done: false, text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                blocks.append(.bullet(String(trimmed.dropFirst(2))))
            } else if let numbered = parseNumbered(trimmed) {
                blocks.append(numbered)
            } else if trimmed.hasPrefix("> ") {
                blocks.append(.quote(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix(">") {
                blocks.append(.quote(String(trimmed.dropFirst(1))))
            } else {
                blocks.append(.paragraph(trimmed))
            }
        }
        if let lines = codeLines { blocks.append(.code(lines)) } // unclosed fence
        return blocks
    }

    private static func parseHeading(_ line: String) -> Block? {
        for level in (1...4).reversed() {
            let prefix = String(repeating: "#", count: level) + " "
            if line.hasPrefix(prefix) {
                return .heading(level: level, text: String(line.dropFirst(prefix.count)))
            }
        }
        return nil
    }

    private static func parseNumbered(_ line: String) -> Block? {
        guard let dotIndex = line.firstIndex(of: "."), line.index(after: dotIndex) < line.endIndex else { return nil }
        let numberPart = line[line.startIndex..<dotIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy(\.isNumber),
              line[line.index(after: dotIndex)] == " " else { return nil }
        return .numbered(number: String(numberPart), text: String(line[line.index(dotIndex, offsetBy: 2)...]))
    }

    // MARK: Rendering

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(.system(size: headingSize(level), weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, level == 1 ? 6 : 4)
                .padding(.bottom, 1)

        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•").foregroundStyle(theme.accent)
                Text(inline(text)).font(.system(size: 12))
            }
            .padding(.leading, 4)

        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.accent)
                Text(inline(text)).font(.system(size: 12))
            }
            .padding(.leading, 4)

        case .task(let done, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11))
                    .foregroundStyle(done ? theme.accent : Color.secondary)
                Text(inline(text))
                    .font(.system(size: 12))
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? Color.secondary : theme.textPrimary)
            }
            .padding(.leading, 4)

        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(theme.accent.opacity(0.6))
                    .frame(width: 3)
                Text(inline(text))
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

        case .code(let lines):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(lines.joined(separator: "\n"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.panelBorder, lineWidth: 1))
            .padding(.vertical, 2)

        case .divider:
            Divider().overlay(theme.panelBorder).padding(.vertical, 4)

        case .paragraph(let text):
            Text(inline(text))
                .font(.system(size: 12))
                .foregroundStyle(theme.textPrimary)

        case .blank:
            Spacer().frame(height: 4)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 17
        case 2: return 15
        case 3: return 13.5
        default: return 12.5
        }
    }

    /// Inline markdown (bold, italic, `code`, links)
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
