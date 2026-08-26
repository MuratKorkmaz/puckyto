import SwiftUI

/// Blinking status dot (Executing / Idle)
struct StatusDot: View {
    let active: Bool
    let color: Color

    var body: some View {
        Circle()
            .fill(active ? color : Color.gray.opacity(0.5))
            .frame(width: 8, height: 8)
            .shadow(color: active ? color.opacity(0.8) : .clear, radius: 4)
    }
}

/// Small informational chip
struct Chip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9))
            }
            Text(text).font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.14), in: Capsule())
        .foregroundStyle(tint)
        .lineLimit(1)
    }
}

/// Panel header
struct PanelHeader: View {
    let title: String
    let systemImage: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

/// Keeps a dialog window above the main window: the dialog never falls behind, even
/// when the main window is clicked (floating level). Moving and resizing are unaffected.
struct DialogFloating: NSViewRepresentable {
    private final class FloatView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.level = .floating
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        }
    }

    func makeNSView(context: Context) -> NSView { FloatView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Formats a byte count for humans
func formatBytes(_ bytes: Int) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .memory
    return f.string(fromByteCount: Int64(bytes))
}

func formatTokens(_ tokens: Int) -> String {
    if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
    if tokens >= 1_000 { return String(format: "%.1fk", Double(tokens) / 1_000) }
    return "\(tokens)"
}
