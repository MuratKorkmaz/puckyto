import SwiftUI

/// Settings: each section is a row — clicking one opens its own editing dialog.
/// The notification toggle and the usage chart stay in the panel.
struct SettingsPanel: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    /// Usage chart filter: nil = all workspaces
    @State private var usageWorkspaceID: UUID?

    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Settings", systemImage: "gearshape.fill")

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    languageSection
                    Divider().overlay(theme.panelBorder)

                    settingsRow(
                        icon: "paintpalette.fill",
                        title: L("Tema"),
                        detail: "\(store.currentTheme.name) · \(Int(store.themeSpec.fontSize ?? store.terminalFontSize))pt",
                        tint: theme.accent
                    ) { openWindow(id: "dialog-theme") }

                    settingsRow(
                        icon: "cpu.fill",
                        title: L("AI Modelleri"),
                        detail: Lf("%@ model", AgentProvider.allCases.map { store.models(for: $0).count }.reduce(0, +)),
                        tint: theme.accent
                    ) { openWindow(id: "dialog-models") }

                    settingsRow(
                        icon: "square.on.square",
                        title: L("Ajan Şablonları"),
                        detail: Lf("%@ şablon", store.agentTemplates.count),
                        tint: theme.accent
                    ) { openWindow(id: "dialog-templates") }

                    settingsRow(
                        icon: "bolt.fill",
                        title: L("Hızlı Komutlar"),
                        detail: Lf("%@ komut", store.savedPrompts.count),
                        tint: theme.accent
                    ) { openWindow(id: "dialog-prompts") }

                    Divider().overlay(theme.panelBorder)
                    notificationsSection
                    Divider().overlay(theme.panelBorder)
                    usageSection
                }
                .padding(12)
            }
        }
    }

    /// A clickable settings row: icon + title + current value + chevron
    private func settingsRow(icon: String, title: String, detail: String, tint: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(tint)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.panelBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L("Dil"), systemImage: "globe")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textSecondary)

            Picker("", selection: $store.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text("\(lang.flag) \(lang.displayName)").tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(L("Arayüz dili. Ajanlara gönderilen sistem promptu da bu dilde yazılır — etkisi için ajanı yeniden başlat."))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L("Bildirimler"), systemImage: "bell.badge.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textSecondary)

            Toggle(isOn: $store.notificationsEnabled) {
                Text(L("Ajan yanıtını bitirince ve onay beklerken bildir"))
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
        }
    }

    // MARK: - Usage (real tokens, last 7 days)

    private struct UsageDay: Identifiable {
        let id: String      // "2026-07-10"
        let label: String   // "10"
        let input: Int
        let output: Int
        var total: Int { input + output }
    }

    private var usageDays: [UsageDay] {
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "d"

        return (0..<7).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let key = keyFormatter.string(from: date)
            let entries = store.usageLedger.filter {
                $0.day == key && (usageWorkspaceID == nil || $0.workspaceID == usageWorkspaceID)
            }
            return UsageDay(
                id: key,
                label: labelFormatter.string(from: date),
                input: entries.reduce(0) { $0 + $1.input },
                output: entries.reduce(0) { $0 + $1.output }
            )
        }
    }

    private var usageSection: some View {
        let days = usageDays
        let maxTotal = max(days.map(\.total).max() ?? 0, 1)
        let weekTotal = days.reduce(0) { $0 + $1.total }

        return VStack(alignment: .leading, spacing: 8) {
            Label(L("Kullanım — Son 7 Gün"), systemImage: "chart.bar.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textSecondary)

            // Analysis scope: global or a single workspace — selectable even without data
            Picker("", selection: $usageWorkspaceID) {
                Text(L("Tüm Workspace'ler")).tag(UUID?.none)
                ForEach(store.workspaces) { workspace in
                    Text(workspace.name).tag(Optional(workspace.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            if weekTotal == 0 {
                // A meaningful empty state instead of a skeleton of flat bars
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text(usageWorkspaceID == nil
                         ? L("Henüz gerçek token verisi yok")
                         : L("Bu workspace için son 7 günde veri yok"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(L("Bir Claude ajanı çalıştırdığında günlük kullanım burada birikmeye başlar."))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.panelBorder, lineWidth: 1))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(days) { day in
                            VStack(spacing: 3) {
                                if day.total == maxTotal && day.total > 0 {
                                    Text(formatTokens(day.total))
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(theme.textSecondary)
                                }
                                UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                                    .fill(day.total > 0 ? theme.accent : theme.panelBorder.opacity(0.6))
                                    .frame(height: day.total > 0
                                           ? max(6, CGFloat(day.total) / CGFloat(maxTotal) * 58)
                                           : 2)
                                    .frame(maxWidth: .infinity)
                                Text(day.label)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .help(Lf("%@ — giriş: %@, çıkış: %@, toplam: %@", day.id, formatTokens(day.input), formatTokens(day.output), formatTokens(day.total)))
                        }
                    }
                    .frame(height: 86, alignment: .bottom)

                    HStack {
                        Text(L("Haftalık toplam"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formatTokens(weekTotal)) token")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
                .padding(10)
                .background(theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.panelBorder, lineWidth: 1))

                // Per-workspace breakdown in the global view
                if usageWorkspaceID == nil {
                    workspaceBreakdown
                }
            }
        }
    }

    /// Last 7 days totalled per workspace (highest first)
    private var workspaceBreakdown: some View {
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        let dayKeys = Set((0..<7).map { offset -> String in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return keyFormatter.string(from: date)
        })
        let totals = store.workspaces.map { workspace -> (name: String, id: UUID, total: Int) in
            let total = store.usageLedger
                .filter { dayKeys.contains($0.day) && $0.workspaceID == workspace.id }
                .reduce(0) { $0 + $1.total }
            return (workspace.name, workspace.id, total)
        }.sorted { $0.total > $1.total }
        let maxTotal = max(totals.first?.total ?? 0, 1)

        return VStack(alignment: .leading, spacing: 5) {
            Text(L("WORKSPACE KIRILIMI"))
                .font(.system(size: 8.5, weight: .black))
                .foregroundStyle(.tertiary)
            ForEach(totals, id: \.id) { row in
                HStack(spacing: 8) {
                    Text(row.name)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .frame(width: 90, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.panelBorder.opacity(0.4))
                            Capsule()
                                .fill(theme.accent)
                                .frame(width: max(2, geo.size.width * CGFloat(row.total) / CGFloat(maxTotal)))
                        }
                    }
                    .frame(height: 5)
                    Text(formatTokens(row.total))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 46, alignment: .trailing)
                }
                .onTapGesture { usageWorkspaceID = row.id }
                .help(Lf("Tıkla: sadece %@ analizini gör", row.name))
            }
        }
        .padding(10)
        .background(theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.panelBorder, lineWidth: 1))
    }
}

// MARK: - Theme dialog

struct ThemeSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L("Tema"), systemImage: "paintpalette.fill")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Kapat")) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(store.allThemes) { definition in
                        themeCard(definition)
                    }
                }
                .padding(14)
            }

            Divider()

            // Custom theme management: read from JSON files
            HStack(spacing: 10) {
                Button {
                    let url = store.createCustomTheme()
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label(L("Yeni Tema (JSON)"), systemImage: "plus.circle.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)
                .help(L("Seçili temanın kopyasıyla yeni bir JSON dosyası oluşturur ve Finder'da gösterir"))

                Button {
                    NSWorkspace.shared.open(AppStore.themesDirectory)
                } label: {
                    Label(L("Klasörü Aç"), systemImage: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)

                Button {
                    store.loadCustomThemes()
                } label: {
                    Label(L("Yenile"), systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help(L("JSON dosyalarını diskten yeniden okur"))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
            themeFontSection

            Text(L("Özel temalar `themes/` klasöründeki JSON dosyalarından okunur. Renk alanları: name, background, panel, panelBorder, accent, textPrimary, textSecondary, terminalBackground, terminalForeground, cursor (hepsi \"RRGGBB\" hex) ve ansi (16 hex renk). Font için: fontFamily (aile adı) ve fontSize. Eksik alanlar One Dark Pro'dan/genel ayardan tamamlanır. Dosyayı düzenledikten sonra \"Yenile\"ye bas."))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(minWidth: 440, idealWidth: 490, maxWidth: .infinity,
               minHeight: 440, idealHeight: 520, maxHeight: .infinity)
    }

    // MARK: Terminal font (global + theme-specific)

    /// Installed fixed-pitch (monospace) font families
    private var monospacedFamilies: [String] {
        NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            return font.isFixedPitch
        }.sorted()
    }

    private var themeFontSection: some View {
        let current = store.currentTheme
        let override = current.spec.fontName != nil || current.spec.fontSize != nil

        return VStack(alignment: .leading, spacing: 8) {
            Label(L("Terminal Yazı Tipi"), systemImage: "textformat")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textSecondary)

            if override {
                HStack(spacing: 6) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(current.spec.accent)
                    Text(Lf("Bu tema kendi fontunu tanımlıyor: %@ · %@ pt", current.spec.fontName ?? "genel aile", String(format: "%.1f", current.spec.fontSize ?? store.terminalFontSize)))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !current.isBuiltin {
                        Button(L("Kaldır")) {
                            store.setThemeFont(family: nil, size: nil, forCustom: current)
                        }
                        .controlSize(.mini)
                        .help(L("Tema fontunu sil; genel ayara dönülür"))
                    }
                }
                .padding(6)
                .background(theme.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 8) {
                Picker("", selection: $store.terminalFontName) {
                    Text(L("Otomatik (Nerd Font algıla)")).tag("")
                    ForEach(monospacedFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240)

                Stepper(
                    value: $store.terminalFontSize,
                    in: 9...20,
                    step: 0.5
                ) {
                    Text(String(format: "%.1f pt", store.terminalFontSize))
                        .font(.system(size: 11, design: .monospaced))
                }

                Spacer()

                if !current.isBuiltin {
                    Button {
                        let resolved = TerminalController.resolveTerminalFont(
                            name: store.terminalFontName, size: 12
                        )
                        let family = store.terminalFontName.isEmpty
                            ? (resolved.familyName ?? resolved.fontName)
                            : store.terminalFontName
                        store.setThemeFont(family: family, size: store.terminalFontSize, forCustom: current)
                    } label: {
                        Label(L("Bu Temaya Yaz"), systemImage: "arrow.down.doc")
                            .font(.system(size: 10.5))
                    }
                    .buttonStyle(.bordered)
                    .help(L("Seçili fontu bu temanın JSON'una kaydet — tema seçilince hep bu fontla gelir"))
                }
            }

            Text(override
                 ? L("Genel ayar, tema fontu tanımlı olduğu sürece bu temada kullanılmaz.")
                 : L("Bu genel ayardır — tüm temalarda geçerli. Prompt ikonları (p10k/starship) için \"Otomatik\" kurulu Nerd Font'u bulur."))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Theme card: mini terminal preview + name + (for custom themes) a delete button
    private func themeCard(_ definition: ThemeDefinition) -> some View {
        let isSelected = store.themeID == definition.id
        return Button {
            store.themeID = definition.id
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Circle().fill(.red.opacity(0.8)).frame(width: 7, height: 7)
                        Circle().fill(.yellow.opacity(0.8)).frame(width: 7, height: 7)
                        Circle().fill(.green.opacity(0.8)).frame(width: 7, height: 7)
                    }
                    Text(L("$ puckyto çalıştır"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(nsColor: definition.spec.terminalForeground))
                    Text(L("▊ ajan hazır"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(definition.spec.accent)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: definition.spec.terminalBackground))

                HStack(spacing: 6) {
                    Text(definition.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    if !definition.isBuiltin {
                        Chip(text: "JSON", tint: definition.spec.accent)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(definition.spec.accent)
                    }
                    if !definition.isBuiltin {
                        Button {
                            store.deleteCustomTheme(definition)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.red.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                        .help(L("Temayı sil (dosya çöpe taşınır)"))
                    }
                }
                .padding(8)
                .background(definition.spec.panel)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? definition.spec.accent : theme.panelBorder,
                            lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model catalog dialog

struct ModelsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var provider: AgentProvider = .claude
    @State private var rows: [ModelOption] = []

    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L("AI Sağlayıcı Modelleri"), systemImage: "cpu.fill")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Kapat")) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: $provider) {
                    ForEach(AgentProvider.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: provider) { _, newProvider in
                    rows = store.models(for: newProvider)
                }

                HStack(spacing: 6) {
                    Text(L("Görünen Ad")).frame(maxWidth: .infinity, alignment: .leading)
                    Text(L("CLI Kimliği")).frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(width: 24)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach($rows) { $row in
                            HStack(spacing: 6) {
                                TextField("Opus 4.8", text: $row.label)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                TextField("claude-opus-4-8", text: $row.value)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11, design: .monospaced))
                                Button {
                                    rows.removeAll { $0.uid == row.uid }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red.opacity(0.75))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(minHeight: 160, maxHeight: .infinity)
                .onChange(of: rows) { _, _ in persist() }

                HStack {
                    Button {
                        rows.append(ModelOption(label: "", value: ""))
                    } label: {
                        Label(L("Model Ekle"), systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(provider.color)

                    Spacer()

                    Button {
                        store.resetModels(for: provider)
                        rows = provider.defaultModels
                    } label: {
                        Label(L("Varsayılanlar"), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Text(Lf("Yeni bir model çıktığında buraya ekle: sol kutuya menüde görünecek adı, sağ kutuya `%@` CLI'sinin kabul ettiği model kimliğini yaz. Agents panelindeki listeye anında yansır.", provider.executable))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
        }
        .frame(minWidth: 460, idealWidth: 520, maxWidth: .infinity,
               minHeight: 400, idealHeight: 460, maxHeight: .infinity)
        .onAppear { rows = store.models(for: provider) }
    }

    private func persist() {
        let cleaned = rows.filter {
            !$0.label.trimmingCharacters(in: .whitespaces).isEmpty ||
            !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }
        store.setModels(cleaned, for: provider)
    }
}

// MARK: - Agent templates dialog

/// Templates: the list on the left (add/delete), the selected template's full editor on the right.
struct TemplatesSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var rulesText = ""
    @State private var showEmojiPicker = false

    private var theme: ThemeSpec { store.themeSpec }

    private var selectedIndex: Int? {
        guard let id = selectedID else { return nil }
        return store.agentTemplates.firstIndex { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L("Ajan Şablonları"), systemImage: "square.on.square")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Kapat")) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 0) {
                // Left: template list
                VStack(spacing: 0) {
                    List(selection: $selectedID) {
                        ForEach(store.agentTemplates) { template in
                            HStack(spacing: 6) {
                                Text(template.emoji)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(template.title)
                                        .font(.system(size: 11, weight: .medium))
                                    Text(template.provider.displayName)
                                        .font(.system(size: 8.5))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .tag(template.id)
                        }
                    }
                    .listStyle(.plain)

                    Divider()

                    HStack(spacing: 8) {
                        Button {
                            let newTemplate = AgentTemplate(
                                title: L("Yeni Şablon"), emoji: "🤖", task: "", rules: []
                            )
                            store.agentTemplates.append(newTemplate)
                            select(newTemplate.id)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 20, height: 18)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(L("Şablon ekle"))

                        Button {
                            if let id = selectedID {
                                store.agentTemplates.removeAll { $0.id == id }
                                select(store.agentTemplates.first?.id)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 20, height: 18)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(selectedID == nil)
                        .help(L("Seçili şablonu sil"))

                        Spacer()

                        Button {
                            store.agentTemplates = AgentTemplate.defaults
                            select(store.agentTemplates.first?.id)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .frame(width: 20, height: 18)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(L("Varsayılan şablonlara dön"))
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .frame(width: 190)

                Divider()

                // Right: selected template editor
                if let index = selectedIndex {
                    templateEditor(index: index)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 26))
                            .foregroundStyle(.tertiary)
                        Text(L("Düzenlemek için soldan bir şablon seç"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 580, idealWidth: 660, maxWidth: .infinity,
               minHeight: 430, idealHeight: 480, maxHeight: .infinity)
        .onAppear { select(store.agentTemplates.first?.id) }
    }

    private func select(_ id: UUID?) {
        selectedID = id
        if let idx = store.agentTemplates.firstIndex(where: { $0.id == id }) {
            rulesText = store.agentTemplates[idx].rules.joined(separator: "\n")
        } else {
            rulesText = ""
        }
    }

    private func templateEditor(index: Int) -> some View {
        let binding = Binding(
            get: { store.agentTemplates[index] },
            set: { store.agentTemplates[index] = $0 }
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        showEmojiPicker.toggle()
                    } label: {
                        Text(binding.wrappedValue.emoji.isEmpty ? "🤖" : binding.wrappedValue.emoji)
                            .font(.system(size: 17))
                            .frame(width: 40, height: 24)
                            .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.panelBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showEmojiPicker, arrowEdge: .bottom) {
                        EmojiPickerView(selected: binding.emoji)
                    }

                    TextField(L("Şablon adı"), text: binding.title)
                        .textFieldStyle(.roundedBorder)
                }

                label(L("AI Sağlayıcı"))
                Picker("", selection: binding.provider) {
                    ForEach(AgentProvider.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: binding.wrappedValue.provider) { _, newProvider in
                    if !store.models(for: newProvider).contains(where: { $0.value == binding.wrappedValue.model }) {
                        binding.wrappedValue.model = ""
                    }
                    if !newProvider.efforts.contains(binding.wrappedValue.effort) {
                        binding.wrappedValue.effort = ""
                    }
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        label("Model")
                        Picker("", selection: binding.model) {
                            Text(L("Varsayılan")).tag("")
                            ForEach(store.models(for: binding.wrappedValue.provider)) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                    if !binding.wrappedValue.provider.efforts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            label("Effort")
                            Picker("", selection: binding.effort) {
                                Text(L("Varsayılan")).tag("")
                                ForEach(binding.wrappedValue.provider.efforts, id: \.self) { effort in
                                    Text(effort).tag(effort)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                label(L("Görev Tanımı"))
                TextEditor(text: binding.task)
                    .font(.system(size: 11))
                    .scrollContentBackground(.hidden)
                    .frame(height: 70)
                    .padding(4)
                    .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

                label(L("Kurallar (her satır bir kural)"))
                TextEditor(text: $rulesText)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(height: 80)
                    .padding(4)
                    .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .onChange(of: rulesText) { _, newValue in
                        binding.wrappedValue.rules = newValue.split(separator: "\n").map(String.init)
                    }

                Text(L("Değişiklikler anında kaydedilir. Şablonu bir terminale uygulamak için: Agents paneli → \"Şablondan Uygula\"."))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
        }
        .onChange(of: selectedID) { _, _ in
            if let idx = selectedIndex {
                rulesText = store.agentTemplates[idx].rules.joined(separator: "\n")
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.textSecondary)
    }
}
