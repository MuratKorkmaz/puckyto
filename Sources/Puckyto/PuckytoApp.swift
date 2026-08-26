import SwiftUI
import AppKit

@MainActor
private func focusedController() -> TerminalController? {
    guard let id = AppStore.shared.focusedSession?.id else { return nil }
    return TerminalRegistry.shared.existingController(for: id)
}

@main
struct PuckytoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .frame(minWidth: 1200, minHeight: 740)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1440, height: 920)
        .defaultPosition(.center)
        .commands {
            CommandGroup(after: .newItem) {
                Button(L("Yeni Terminal")) { AppStore.shared.addSession() }
                    .keyboardShortcut("t", modifiers: .command)
                Button(L("Yeni Workspace")) { AppStore.shared.addWorkspace() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button(L("Paneli Gizle/Göster")) { AppStore.shared.panelCollapsed.toggle() }
                    .keyboardShortcut("\\", modifiers: .command)
                Button(L("Terminalde Ara")) {
                    let store = AppStore.shared
                    store.searchSessionID = store.searchSessionID == store.focusedSession?.id
                        ? nil : store.focusedSession?.id
                }
                .keyboardShortcut("f", modifiers: .command)
                Button(L("Sayfa Yukarı Kaydır")) { focusedController()?.pageUp() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Button(L("Sayfa Aşağı Kaydır")) { focusedController()?.pageDown() }
                    .keyboardShortcut(.downArrow, modifiers: .command)
                Button(L("En Alta İn")) { focusedController()?.scrollToBottom() }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
            }
        }

        // Menu bar: agent status while the app is in the background + one-click focus
        MenuBarExtra("Puckyto", systemImage: "point.3.connected.trianglepath.dotted") {
            MenuBarStatusView()
                .environmentObject(AppStore.shared)
        }

        // Settings/tool dialogs are real windows: movable, with a minimum size and freely
        // resizable above it (.contentMinSize: the lower bound comes from the content)
        Window(L("Tema"), id: "dialog-theme") {
            ThemeSheet()
                .environmentObject(AppStore.shared)
                .preferredColorScheme(.dark)
                .background(DialogFloating())
        }
        .windowResizability(.contentMinSize)

        Window(L("AI Modelleri"), id: "dialog-models") {
            ModelsSheet()
                .environmentObject(AppStore.shared)
                .preferredColorScheme(.dark)
                .background(DialogFloating())
        }
        .windowResizability(.contentMinSize)

        Window(L("Ajan Şablonları"), id: "dialog-templates") {
            TemplatesSheet()
                .environmentObject(AppStore.shared)
                .preferredColorScheme(.dark)
                .background(DialogFloating())
        }
        .windowResizability(.contentMinSize)

        Window(L("Görev Gönder"), id: "dialog-dispatch") {
            TaskDispatchSheet()
                .environmentObject(AppStore.shared)
                .preferredColorScheme(.dark)
                .background(DialogFloating())
        }
        .windowResizability(.contentMinSize)

        WindowGroup(L("Ortak Pano"), id: "dialog-board", for: UUID.self) { $workspaceID in
            if let workspaceID {
                BoardSheet(workspaceID: workspaceID)
                    .environmentObject(AppStore.shared)
                    .preferredColorScheme(.dark)
                    .background(DialogFloating())
            }
        }
        .windowResizability(.contentMinSize)

        Window(L("Hızlı Komutlar"), id: "dialog-prompts") {
            PromptsSheet()
                .environmentObject(AppStore.shared)
                .preferredColorScheme(.dark)
                .background(DialogFloating())
        }
        .windowResizability(.contentMinSize)

        WindowGroup(L("Görev Kuyruğu"), id: "dialog-queue", for: UUID.self) { $sessionID in
            if let sessionID {
                QueueSheet(sessionID: sessionID)
                    .environmentObject(AppStore.shared)
                    .preferredColorScheme(.dark)
                    .background(DialogFloating())
            }
        }
        .windowResizability(.contentMinSize)

        Window(L("A/B Koşusu"), id: "dialog-ab") {
            ABRunSheet()
                .environmentObject(AppStore.shared)
                .preferredColorScheme(.dark)
                .background(DialogFloating())
        }
        .windowResizability(.contentMinSize)

        Window(L("Gönderim Geçmişi"), id: "dialog-sent") {
            SentHistorySheet()
                .environmentObject(AppStore.shared)
                .preferredColorScheme(.dark)
                .background(DialogFloating())
        }
        .windowResizability(.contentMinSize)

        WindowGroup(L("Sistem Promptu"), id: "dialog-prompt", for: UUID.self) { $sessionID in
            if let sessionID {
                PromptPreviewSheet(sessionID: sessionID)
                    .environmentObject(AppStore.shared)
                    .preferredColorScheme(.dark)
                    .background(DialogFloating())
            }
        }
        .windowResizability(.contentMinSize)

        WindowGroup("CLAUDE.md", id: "dialog-claudemd", for: UUID.self) { $sessionID in
            if let sessionID {
                ClaudeMdSheet(sessionID: sessionID)
                    .environmentObject(AppStore.shared)
                    .preferredColorScheme(.dark)
                    .background(DialogFloating())
            }
        }
        .windowResizability(.contentMinSize)

        WindowGroup(L("Claude Oturum Geçmişi"), id: "dialog-history", for: UUID.self) { $sessionID in
            if let sessionID {
                SessionHistorySheet(sessionID: sessionID)
                    .environmentObject(AppStore.shared)
                    .preferredColorScheme(.dark)
                    .background(DialogFloating())
            }
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    /// Once the ⌘W flow has confirmed, applicationShouldTerminate must not ask again
    static var quitConfirmed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed for the window to come forward when running as an SPM executable
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Notifier.shared.setup()

        // ⌘W: close the focused terminal with a confirmation; quit (also confirmed) when none remain.
        // Dialog windows (floating) keep closing with ⌘W as usual.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "w" else { return event }
            if NSApp.keyWindow?.level == .floating { return event }
            MainActor.assumeIsolated { AppDelegate.handleCloseShortcut() }
            return nil
        }
    }

    /// ⌘W: the focused terminal first, then the app once the terminals are gone — all confirmed.
    @MainActor
    static func handleCloseShortcut() {
        let store = AppStore.shared
        if let session = store.focusedSession {
            let controller = TerminalRegistry.shared.existingController(for: session.id)
            let alert = NSAlert()
            alert.messageText = Lf("«%@» terminali kapatılsın mı?", session.name)
            alert.informativeText = controller?.isAgentSessionOpen == true
                ? L("Bu terminalde aktif bir AI oturumu var — kapatınca sonlanır.")
                : L("Çalışan kabuk süreci sonlanacak.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Kapat"))
            alert.addButton(withTitle: L("Vazgeç"))
            if alert.runModal() == .alertFirstButtonReturn {
                store.removeSession(session.id)
            }
        } else if confirmQuit() {
            quitConfirmed = true
            NSApp.terminate(nil)
        }
    }

    /// "Are you sure?" — asks along with the number of open terminals/agents.
    @MainActor
    static func confirmQuit() -> Bool {
        let controllers = TerminalRegistry.shared.allControllers()
        let agents = controllers.filter { $0.isAgentSessionOpen }.count
        let alert = NSAlert()
        alert.messageText = L("Puckyto'yu kapatmak istediğine emin misin?")
        alert.informativeText = agents > 0
            ? Lf("%@ terminal açık, %@ ajan oturumu aktif. Kapatınca tüm işlemler sonlanır.", controllers.count, agents)
            : controllers.isEmpty
                ? L("Uygulama kapatılacak.")
                : Lf("%@ terminal açık. Kapatınca kabuk süreçleri sonlanır.", controllers.count)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("Kapat"))
        alert.addButton(withTitle: L("Vazgeç"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// ⌘Q / quit from the menu: never terminates without a confirmation.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.quitConfirmed { return .terminateNow }
        let confirmed = MainActor.assumeIsolated { Self.confirmQuit() }
        return confirmed ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in AppStore.shared.saveNow() }
        for controller in TerminalRegistry.shared.allControllers() {
            controller.terminate()
        }
    }

    /// Closing the window with the red button keeps the app (and its terminals) alive —
    /// reopen it from the Dock or the menu bar. Quitting only happens through the
    /// confirmed ⌘Q / ⌘W flow.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
