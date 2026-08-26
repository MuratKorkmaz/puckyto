import Foundation
import SwiftUI

// MARK: - Tema

/// The five most popular VS Code themes, with their official color palettes.
enum ThemeKind: String, CaseIterable, Codable, Identifiable {
    case oneDarkPro
    case dracula
    case githubDark
    case tokyoNight
    case monokaiPro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneDarkPro: return "One Dark Pro"
        case .dracula: return "Dracula"
        case .githubDark: return "GitHub Dark"
        case .tokyoNight: return "Tokyo Night"
        case .monokaiPro: return "Monokai Pro"
        }
    }

    var spec: ThemeSpec { ThemeSpec.all[self]! }
}

/// A theme definition applied to both the SwiftUI interface and the terminal's ANSI palette.
struct ThemeSpec {
    let background: Color        // uygulama zemini
    let panel: Color             // yan paneller / kartlar
    let panelBorder: Color
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color
    let terminalBackground: NSColor
    let terminalForeground: NSColor
    let cursor: NSColor
    /// The 16 ANSI colors as "RRGGBB" hex (0-7 normal, 8-15 bright)
    let ansi: [String]
    /// A theme may define its own terminal font (nil = use the global setting)
    var fontName: String? = nil
    var fontSize: Double? = nil

    static let all: [ThemeKind: ThemeSpec] = [
        // One Dark Pro — the most downloaded VS Code theme (an Atom legacy)
        .oneDarkPro: ThemeSpec(
            background: Color(hex: "21252B"),
            panel: Color(hex: "282C34"),
            panelBorder: Color(hex: "3E4451"),
            accent: Color(hex: "61AFEF"),
            textPrimary: Color(hex: "ABB2BF"),
            textSecondary: Color(hex: "7F848E"),
            terminalBackground: NSColor(hex: "282C34"),
            terminalForeground: NSColor(hex: "ABB2BF"),
            cursor: NSColor(hex: "61AFEF"),
            ansi: ["2C313C", "E06C75", "98C379", "E5C07B", "61AFEF", "C678DD", "56B6C2", "ABB2BF",
                   "5C6370", "E06C75", "98C379", "E5C07B", "61AFEF", "C678DD", "56B6C2", "FFFFFF"]
        ),
        // Dracula Official — high-contrast purple/pink
        .dracula: ThemeSpec(
            background: Color(hex: "21222C"),
            panel: Color(hex: "282A36"),
            panelBorder: Color(hex: "44475A"),
            accent: Color(hex: "BD93F9"),
            textPrimary: Color(hex: "F8F8F2"),
            textSecondary: Color(hex: "8A8FA3"),
            terminalBackground: NSColor(hex: "282A36"),
            terminalForeground: NSColor(hex: "F8F8F2"),
            cursor: NSColor(hex: "FF79C6"),
            ansi: ["21222C", "FF5555", "50FA7B", "F1FA8C", "BD93F9", "FF79C6", "8BE9FD", "F8F8F2",
                   "6272A4", "FF6E6E", "69FF94", "FFFFA5", "D6ACFF", "FF92DF", "A4FFFF", "FFFFFF"]
        ),
        // GitHub Dark — GitHub's official dark palette
        .githubDark: ThemeSpec(
            background: Color(hex: "010409"),
            panel: Color(hex: "0D1117"),
            panelBorder: Color(hex: "30363D"),
            accent: Color(hex: "58A6FF"),
            textPrimary: Color(hex: "C9D1D9"),
            textSecondary: Color(hex: "8B949E"),
            terminalBackground: NSColor(hex: "0D1117"),
            terminalForeground: NSColor(hex: "C9D1D9"),
            cursor: NSColor(hex: "58A6FF"),
            ansi: ["484F58", "FF7B72", "3FB950", "D29922", "58A6FF", "BC8CFF", "39C5CF", "B1BAC4",
                   "6E7681", "FFA198", "56D364", "E3B341", "79C0FF", "D2A8FF", "56D4DD", "F0F6FC"]
        ),
        // Tokyo Night — deep navy with soft neon
        .tokyoNight: ThemeSpec(
            background: Color(hex: "16161E"),
            panel: Color(hex: "1A1B26"),
            panelBorder: Color(hex: "292E42"),
            accent: Color(hex: "7AA2F7"),
            textPrimary: Color(hex: "C0CAF5"),
            textSecondary: Color(hex: "787C99"),
            terminalBackground: NSColor(hex: "1A1B26"),
            terminalForeground: NSColor(hex: "C0CAF5"),
            cursor: NSColor(hex: "7AA2F7"),
            ansi: ["15161E", "F7768E", "9ECE6A", "E0AF68", "7AA2F7", "BB9AF7", "7DCFFF", "A9B1D6",
                   "414868", "F7768E", "9ECE6A", "E0AF68", "7AA2F7", "BB9AF7", "7DCFFF", "C0CAF5"]
        ),
        // Monokai Pro — warm gray background, vivid accents
        .monokaiPro: ThemeSpec(
            background: Color(hex: "221F22"),
            panel: Color(hex: "2D2A2E"),
            panelBorder: Color(hex: "403E41"),
            accent: Color(hex: "FFD866"),
            textPrimary: Color(hex: "FCFCFA"),
            textSecondary: Color(hex: "939293"),
            terminalBackground: NSColor(hex: "2D2A2E"),
            terminalForeground: NSColor(hex: "FCFCFA"),
            cursor: NSColor(hex: "FFD866"),
            ansi: ["403E41", "FF6188", "A9DC76", "FFD866", "FC9867", "AB9DF2", "78DCE8", "FCFCFA",
                   "727072", "FF6188", "A9DC76", "FFD866", "FC9867", "AB9DF2", "78DCE8", "FFFFFF"]
        )
    ]
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8) & 0xFF) / 255.0,
            blue: Double(v & 0xFF) / 255.0
        )
    }
}

extension NSColor {
    convenience init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(
            srgbRed: CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8) & 0xFF) / 255.0,
            blue: CGFloat(v & 0xFF) / 255.0,
            alpha: 1.0
        )
    }

    /// "RRGGBB" — for writing into a custom theme's JSON
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "%02X%02X%02X",
                      Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)),
                      Int(round(c.blueComponent * 255)))
    }
}

extension Color {
    var hexString: String { NSColor(self).hexString }
}

// MARK: - Theme definition (built-ins + custom themes from JSON)

/// A theme listed in the UI: either built-in (ThemeKind) or from a themes/*.json file.
struct ThemeDefinition: Identifiable {
    let id: String          // built-ins: rawValue; custom: "custom-<fileName>"
    let name: String
    let spec: ThemeSpec
    let isBuiltin: Bool

    static let builtins: [ThemeDefinition] = ThemeKind.allCases.map {
        ThemeDefinition(id: $0.rawValue, name: $0.displayName, spec: $0.spec, isBuiltin: true)
    }
}

/// Custom theme JSON format — all colors are "RRGGBB" hex and every field is optional
/// (missing fields fall back to One Dark Pro). `ansi` must hold exactly 16 colors.
struct CustomThemeFile: Codable {
    var name: String?
    var background: String?
    var panel: String?
    var panelBorder: String?
    var accent: String?
    var textPrimary: String?
    var textSecondary: String?
    var terminalBackground: String?
    var terminalForeground: String?
    var cursor: String?
    var ansi: [String]?
    /// Theme-specific terminal font (optional; the global setting applies when absent)
    var fontFamily: String?
    var fontSize: Double?

    /// As a copy of an existing theme (used to seed a new theme file)
    init(name: String, spec: ThemeSpec) {
        self.name = name
        background = spec.background.hexString
        panel = spec.panel.hexString
        panelBorder = spec.panelBorder.hexString
        accent = spec.accent.hexString
        textPrimary = spec.textPrimary.hexString
        textSecondary = spec.textSecondary.hexString
        terminalBackground = spec.terminalBackground.hexString
        terminalForeground = spec.terminalForeground.hexString
        cursor = spec.cursor.hexString
        ansi = spec.ansi
        fontFamily = spec.fontName
        fontSize = spec.fontSize
    }

    func makeSpec() -> ThemeSpec {
        let base = ThemeKind.oneDarkPro.spec
        func c(_ hex: String?, _ fallback: Color) -> Color {
            guard let hex, !hex.isEmpty else { return fallback }
            return Color(hex: hex)
        }
        func n(_ hex: String?, _ fallback: NSColor) -> NSColor {
            guard let hex, !hex.isEmpty else { return fallback }
            return NSColor(hex: hex)
        }
        return ThemeSpec(
            background: c(background, base.background),
            panel: c(panel, base.panel),
            panelBorder: c(panelBorder, base.panelBorder),
            accent: c(accent, base.accent),
            textPrimary: c(textPrimary, base.textPrimary),
            textSecondary: c(textSecondary, base.textSecondary),
            terminalBackground: n(terminalBackground, base.terminalBackground),
            terminalForeground: n(terminalForeground, base.terminalForeground),
            cursor: n(cursor, base.cursor),
            ansi: (ansi?.count == 16 ? ansi! : base.ansi),
            fontName: fontFamily,
            fontSize: fontSize
        )
    }
}

// MARK: - Agent

struct AgentConfig: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = "Ajan"
    var emoji: String = "🤖"
    /// Which AI CLI to use (Claude / ChatGPT / Gemini)
    var provider: AgentProvider = .claude
    /// Model choice (empty = the provider's default, no flag is passed to the CLI)
    var model: String = ""
    /// Effort/reasoning level (empty = default)
    var effort: String = ""
    /// Task description
    var task: String = ""
    /// Rule set (one rule per line)
    var rules: [String] = []
    /// Persistent memory (markdown) — written to a file at agent start and referenced in the prompt
    var memory: String = ""
    /// Whether the agent starts automatically when the terminal opens
    var autoStart: Bool = false
    /// Coordinator: can assign work to other agents through the file queue
    var coordinator: Bool = false
    /// Claude permission mode: "" = ask (default), "plan", "acceptEdits", "bypass"
    var permissionMode: String = ""

    init(id: UUID = UUID(), name: String = "Ajan", emoji: String = "🤖",
         provider: AgentProvider = .claude, model: String = "", effort: String = "",
         task: String = "", rules: [String] = [],
         memory: String = "", autoStart: Bool = false, coordinator: Bool = false,
         permissionMode: String = "") {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.provider = provider
        self.model = model
        self.effort = effort
        self.task = task
        self.rules = rules
        self.memory = memory
        self.autoStart = autoStart
        self.coordinator = coordinator
        self.permissionMode = permissionMode
    }

    /// Older records lack the newer fields; fill the gaps with defaults so the user's
    /// existing state.json stays valid.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Ajan"
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "🤖"
        provider = try c.decodeIfPresent(AgentProvider.self, forKey: .provider) ?? .claude
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        effort = try c.decodeIfPresent(String.self, forKey: .effort) ?? ""
        task = try c.decodeIfPresent(String.self, forKey: .task) ?? ""
        rules = try c.decodeIfPresent([String].self, forKey: .rules) ?? []
        memory = try c.decodeIfPresent(String.self, forKey: .memory) ?? ""
        autoStart = try c.decodeIfPresent(Bool.self, forKey: .autoStart) ?? false
        coordinator = try c.decodeIfPresent(Bool.self, forKey: .coordinator) ?? false
        permissionMode = try c.decodeIfPresent(String.self, forKey: .permissionMode) ?? ""
    }
}

// MARK: - Agent templates

/// A ready-made agent configuration, applied to a terminal with one click.
struct AgentTemplate: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var emoji: String
    var provider: AgentProvider = .claude
    var model: String = ""
    var effort: String = ""
    var task: String
    var rules: [String]

    static var defaults: [AgentTemplate] { Loc.language == .tr ? trDefaults : enDefaults }

    private static let trDefaults: [AgentTemplate] = [
        AgentTemplate(
            title: "Kod Yazıcı", emoji: "🛠",
            task: "Verilen özellikleri uçtan uca geliştir: kodu yaz, derle/çalıştır, hataları düzelt.",
            rules: ["Her değişiklikten sonra derle ve test et", "Büyük değişiklikten önce kısa bir plan sun"]
        ),
        AgentTemplate(
            title: "İnceleyici", emoji: "🔍",
            task: "Yazılan kodu incele: hata, güvenlik açığı ve basitleştirme fırsatlarını raporla.",
            rules: ["Kodu değiştirme, sadece raporla", "Bulguları önem sırasına göre listele"]
        ),
        AgentTemplate(
            title: "Test Uzmanı", emoji: "🧪",
            task: "Eksik testleri tespit edip yaz; mevcut testleri çalıştırıp kırmızıları raporla.",
            rules: ["Önce mevcut test altyapısını keşfet", "Testler geçmeden işi bitmiş sayma"]
        ),
        AgentTemplate(
            title: "Dokümantasyoncu", emoji: "📚",
            task: "Kodu ve kararları belgele: README, mimari notlar ve wiki'yi güncel tut.",
            rules: ["Wiki klasörünü aktif kullan", "Yazdığın örnek komutları çalıştırıp doğrula"]
        ),
    ]

    private static let enDefaults: [AgentTemplate] = [
        AgentTemplate(
            title: "Builder", emoji: "🛠",
            task: "Implement the requested features end to end: write the code, build/run it, fix the errors.",
            rules: ["Build and test after every change", "Outline a short plan before large changes"]
        ),
        AgentTemplate(
            title: "Reviewer", emoji: "🔍",
            task: "Review the written code: report bugs, security issues and simplification opportunities.",
            rules: ["Do not change the code, only report", "List findings by severity"]
        ),
        AgentTemplate(
            title: "Test Engineer", emoji: "🧪",
            task: "Find and write the missing tests; run the existing ones and report the failures.",
            rules: ["Explore the existing test setup first", "Do not call it done until the tests pass"]
        ),
        AgentTemplate(
            title: "Documentarian", emoji: "📚",
            task: "Document the code and decisions: keep the README, architecture notes and wiki current.",
            rules: ["Use the wiki folder actively", "Run the example commands you write to verify them"]
        ),
    ]
}

// MARK: - Quick commands (prompt library)

/// Frequently used prompts, sent with one click from the ⚡ menu in the terminal header.
struct SavedPrompt: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var text: String

    static var defaults: [SavedPrompt] { Loc.language == .tr ? trDefaults : enDefaults }

    private static let trDefaults: [SavedPrompt] = [
        SavedPrompt(title: "Durum raporu", text: "Durum raporu ver: ne üzerinde çalışıyorsun, ne bitti, engelin var mı?"),
        SavedPrompt(title: "Testleri koş & düzelt", text: "Testleri çalıştır; kırmızı olanları sırayla düzelt, sonunda özet ver."),
        SavedPrompt(title: "Değişiklikleri özetle", text: "Bu oturumda yaptığın değişiklikleri madde madde özetle ve wiki'ne not düş."),
        SavedPrompt(title: "Panoyu güncelle", text: "Ortak panoya güncel durumunu yaz: bitenler, süren işler, sıradakiler."),
    ]

    private static let enDefaults: [SavedPrompt] = [
        SavedPrompt(title: "Status report", text: "Give a status report: what are you working on, what is done, are you blocked?"),
        SavedPrompt(title: "Run & fix tests", text: "Run the tests; fix the failing ones one by one, then summarize."),
        SavedPrompt(title: "Summarize changes", text: "Summarize the changes you made in this session as bullets and note them in your wiki."),
        SavedPrompt(title: "Update the board", text: "Write your current status to the shared board: done, in progress, next up."),
    ]
}

// MARK: - Send history

/// A record of every prompt sent to an agent (quick command, broadcast, queue, coordinator, A/B)
struct SentPrompt: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var sessionID: UUID
    var sessionName: String
    var text: String
    var source: String   // "⚡ quick", "📣 broadcast", "⏭ queue", "📮 coordinator", "🧪 a/b", "✍️ manual"
}

// MARK: - Task queue (the next task is sent automatically when the agent goes idle)

struct QueuedTask: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
}

// MARK: - Usage ledger (real token consumption, day × workspace)

struct UsageEntry: Codable, Hashable, Identifiable {
    var day: String          // "2026-07-10"
    var workspaceID: UUID
    var input: Int
    var output: Int

    var id: String { "\(day)-\(workspaceID.uuidString)" }
    var total: Int { input + output }
}

/// A selectable model for a provider: the UI label plus the identifier passed to the CLI.
/// The fields are mutable and Codable because they are edited in Settings;
/// `uid` keeps a row's identity stable while it is being edited.
struct ModelOption: Identifiable, Hashable, Codable {
    var uid: UUID = UUID()
    var label: String
    var value: String
    var id: UUID { uid }

    init(uid: UUID = UUID(), label: String, value: String) {
        self.uid = uid
        self.label = label
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = try c.decodeIfPresent(UUID.self, forKey: .uid) ?? UUID()
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
    }
}

/// Supported AI agent providers. Each has its own CLI, color and tag.
enum AgentProvider: String, Codable, CaseIterable, Identifiable {
    case claude
    case chatgpt
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .chatgpt: return "ChatGPT"
        case .gemini: return "Gemini"
        }
    }

    /// Short tag shown in the terminal header and in lists
    var tag: String {
        switch self {
        case .claude: return "CLAUDE"
        case .chatgpt: return "GPT"
        case .gemini: return "GEMINI"
        }
    }

    /// Brand color — used for the tag chips and the node ring on the neural map
    var color: Color {
        switch self {
        case .claude: return Color(hex: "D97757")   // Anthropic orange
        case .chatgpt: return Color(hex: "10A37F")  // OpenAI green
        case .gemini: return Color(hex: "4C8DF6")   // Google blue
        }
    }

    /// The CLI executed in the terminal
    var executable: String {
        switch self {
        case .claude: return "claude"
        case .chatgpt: return "codex"
        case .gemini: return "gemini"
        }
    }

    /// Built-in model list: `label` is the versioned name shown in the UI, `value` the identifier passed to the CLI.
    /// If the user writes their own list in Settings, it replaces this one
    /// (see AppStore.models(for:)).
    var defaultModels: [ModelOption] {
        switch self {
        case .claude: return [
            ModelOption(label: "Fable 5", value: "claude-fable-5"),
            ModelOption(label: "Opus 4.8", value: "claude-opus-4-8"),
            ModelOption(label: "Sonnet 5", value: "claude-sonnet-5"),
            ModelOption(label: "Haiku 4.5", value: "claude-haiku-4-5-20251001"),
        ]
        case .chatgpt: return [
            ModelOption(label: "GPT-5.1 Codex Max", value: "gpt-5.1-codex-max"),
            ModelOption(label: "GPT-5.1 Codex", value: "gpt-5.1-codex"),
            ModelOption(label: "GPT-5.1 Codex Mini", value: "gpt-5.1-codex-mini"),
            ModelOption(label: "GPT-5.1", value: "gpt-5.1"),
        ]
        case .gemini: return [
            ModelOption(label: "Gemini 3 Pro (preview)", value: "gemini-3-pro-preview"),
            ModelOption(label: "Gemini 2.5 Pro", value: "gemini-2.5-pro"),
            ModelOption(label: "Gemini 2.5 Flash", value: "gemini-2.5-flash"),
        ]
        }
    }

    /// Selectable effort/reasoning levels (an empty array means the provider has none)
    var efforts: [String] {
        switch self {
        case .claude: return ["low", "medium", "high", "xhigh", "max"]       // claude --effort (verified with v2.1.205)
        case .chatgpt: return ["minimal", "low", "medium", "high", "xhigh"]  // codex -c model_reasoning_effort
        case .gemini: return []                                              // the gemini CLI has no effort flag
        }
    }

    /// Passes the task/rules/memory prompt plus the model/effort/permission choices
    /// as the flags each provider's CLI expects.
    func launchCommand(prompt: String, model: String = "", effort: String = "",
                       permissionMode: String = "") -> String {
        let escaped = prompt.replacingOccurrences(of: "'", with: "'\\''")
        var parts: [String] = [executable]
        switch self {
        case .claude:
            if !model.isEmpty { parts.append("--model \(model)") }
            if !effort.isEmpty { parts.append("--effort \(effort)") }
            switch permissionMode {
            case "plan": parts.append("--permission-mode plan")
            case "acceptEdits": parts.append("--permission-mode acceptEdits")
            case "bypass": parts.append("--dangerously-skip-permissions")
            default: break
            }
            parts.append("--append-system-prompt '\(escaped)'")
        case .chatgpt:
            if !model.isEmpty { parts.append("-m \(model)") }
            if !effort.isEmpty { parts.append("-c model_reasoning_effort=\"\(effort)\"") }
            parts.append("'\(escaped)'")
        case .gemini:
            if !model.isEmpty { parts.append("-m \(model)") }
            parts.append("-i '\(escaped)'")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Terminal session and workspace

struct TerminalSessionModel: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = "Terminal"
    var workingDirectory: String = NSHomeDirectory()
    var agent: AgentConfig = AgentConfig()
}

struct WorkspaceModel: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = "Workspace"
    var icon: String = "square.stack.3d.up"
    var sessions: [TerminalSessionModel] = []
    /// Default folder new terminals open in (nil = home directory)
    var defaultDirectory: String?
}

// MARK: - Sidebar sections

enum SidebarSection: String, CaseIterable, Identifiable, Codable {
    case workspaces
    case sessions
    case wiki
    case files
    case agents
    case logs
    case neuralMap
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workspaces: return "Workspaces"
        case .sessions: return "Sessions"
        case .wiki: return "Wiki"
        case .files: return "Files"
        case .agents: return "Agents"
        case .logs: return "Logs"
        case .neuralMap: return "Neural Map"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .workspaces: return "square.stack.3d.up.fill"
        case .sessions: return "terminal.fill"
        case .wiki: return "book.pages.fill"
        case .files: return "folder.fill"
        case .agents: return "brain.head.profile"
        case .logs: return "list.clipboard.fill"
        case .neuralMap: return "point.3.connected.trianglepath.dotted"
        case .settings: return "gearshape.fill"
        }
    }
}

/// The edge the side panel is pinned to
enum PanelPin: String, Codable {
    case left
    case right
}

// MARK: - Wiki note (lives on disk as an .md file)

struct WikiNote: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    var title: String
    var modified: Date
}
