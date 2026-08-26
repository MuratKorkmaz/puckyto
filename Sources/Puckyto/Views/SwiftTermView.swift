import SwiftUI
import SwiftTerm

/// Bridges SwiftTerm's NSView-based terminal into SwiftUI.
struct SwiftTermView: NSViewRepresentable {
    let controller: TerminalController
    /// Theme + font key: changes when the theme JSON is reloaded or the font changes
    let themeKey: String
    let spec: ThemeSpec
    let font: NSFont

    func makeNSView(context: Context) -> PuckytoTermView {
        controller.applyTheme(spec)
        controller.applyFont(font)
        return controller.terminalView
    }

    func updateNSView(_ nsView: PuckytoTermView, context: Context) {
        if context.coordinator.appliedKey != themeKey {
            controller.applyTheme(spec)
            controller.applyFont(font)
            context.coordinator.appliedKey = themeKey
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appliedKey: themeKey)
    }

    final class Coordinator {
        var appliedKey: String
        init(appliedKey: String) { self.appliedKey = appliedKey }
    }
}
