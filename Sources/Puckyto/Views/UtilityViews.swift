import SwiftUI

// MARK: - Menu bar status

/// Shows the status of every agent from the menu bar; clicking a row focuses its terminal.
struct MenuBarStatusView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let counts = store.agentStatusCounts
        Text(Lf("🟢 %@ ajan açık · 🔔 %@ onay bekliyor", counts.running, counts.attention))

        Divider()

        ForEach(store.workspaces) { workspace in
            Section(workspace.name) {
                ForEach(workspace.sessions) { session in
                    Button {
                        store.focusSession(session.id)
                    } label: {
                        Text("\(statusIcon(session.id)) \(session.agent.emoji) \(session.name)")
                    }
                }
            }
        }

        Divider()

        Button(L("Puckyto'yu Öne Getir")) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func statusIcon(_ sessionID: UUID) -> String {
        guard let controller = TerminalRegistry.shared.existingController(for: sessionID) else { return "⚪️" }
        if controller.needsAttention { return "🔔" }
        if controller.isExecuting { return "🟢" }
        if controller.isAgentSessionOpen { return "🟡" }
        return "⚪️"
    }
}

// MARK: - Quick commands (prompt library) window

struct PromptsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L("Hızlı Komutlar"), systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Kapat")) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($store.savedPrompts) { $prompt in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField(L("Başlık"), text: $prompt.title)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, weight: .semibold))
                                Button {
                                    store.savedPrompts.removeAll { $0.id == prompt.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red.opacity(0.75))
                                }
                                .buttonStyle(.plain)
                            }
                            TextField(L("Gönderilecek metin"), text: $prompt.text, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                                .lineLimit(2...4)
                        }
                        .padding(8)
                        .background(theme.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(14)
            }

            Divider()

            HStack {
                Button {
                    store.savedPrompts.append(SavedPrompt(title: "Yeni Komut", text: ""))
                } label: {
                    Label(L("Komut Ekle"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)

                Spacer()

                Button {
                    store.savedPrompts = SavedPrompt.defaults
                } label: {
                    Label(L("Varsayılanlar"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Text(L("Komutlar terminal başlığındaki ⚡ menüsünden tek tıkla o ajana gönderilir."))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 10)
        }
        .frame(minWidth: 440, idealWidth: 490, maxWidth: .infinity,
               minHeight: 380, idealHeight: 440, maxHeight: .infinity)
    }
}

// MARK: - Task queue window

/// An ordered task list per agent: the next one is sent automatically when the agent goes idle.
struct QueueSheet: View {
    let sessionID: UUID
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var newTask = ""

    private var theme: ThemeSpec { store.themeSpec }
    private var session: TerminalSessionModel? { store.session(with: sessionID) }
    private var tasks: [QueuedTask] { store.queue(for: sessionID) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(Lf("Görev Kuyruğu · %@", session?.name ?? "Terminal"), systemImage: "list.number")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(L("Kapat")) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.number")
                        .font(.system(size: 26))
                        .foregroundStyle(.tertiary)
                    Text(L("Kuyruk boş"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(L("Aşağıdan görev ekle: ajan her yanıtını bitirip boşa düştüğünde\nsıradaki görev otomatik gönderilir. Onay beklerken (🔔) gönderilmez."))
                        .font(.system(size: 10))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.accent)
                            Text(task.text)
                                .font(.system(size: 11))
                                .lineLimit(3)
                            Spacer()
                            if index == 0 {
                                Button(L("Şimdi Gönder")) {
                                    var queue = tasks
                                    let first = queue.removeFirst()
                                    store.setQueue(queue, for: sessionID)
                                    store.sendPrompt(first.text, to: sessionID, source: L("⏭ kuyruk"))
                                }
                                .controlSize(.small)
                            }
                            Button {
                                store.setQueue(tasks.filter { $0.id != task.id }, for: sessionID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 3)
                    }
                    .onMove { from, to in
                        var queue = tasks
                        queue.move(fromOffsets: from, toOffset: to)
                        store.setQueue(queue, for: sessionID)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            HStack(spacing: 8) {
                TextField(L("Yeni görev — örn: API testlerini yaz ve çalıştır"), text: $newTask, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .lineLimit(1...3)
                    .onSubmit(addTask)
                Button {
                    addTask()
                } label: {
                    Label(L("Ekle"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
        }
        .frame(minWidth: 460, idealWidth: 520, maxWidth: .infinity,
               minHeight: 380, idealHeight: 440, maxHeight: .infinity)
    }

    private func addTask() {
        let text = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.setQueue(tasks + [QueuedTask(text: text)], for: sessionID)
        newTask = ""
    }
}
