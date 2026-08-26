import SwiftUI

/// The "neural network" of active agents: a central core + workspace nodes + agent nodes.
/// Signal particles flow along the edges, speeding up with the agent's activity.
/// Nodes can be dragged with the mouse; positions are stored normalized (0-1) so the
/// layout survives window resizing.
struct NeuralMapView: View {
    @EnvironmentObject var store: AppStore

    /// Nodes the user moved: key → normalized position (0...1)
    @State private var nodeOverrides: [String: CGPoint] = [:]
    @State private var draggingKey: String?
    /// Grab offset relative to the node center (keeps the node from jumping on drag)
    @State private var dragOffset = CGSize.zero
    /// Whether the threshold was passed: if not, releasing counts as "click → select"
    @State private var hasDragged = false
    /// Stats column width at the moment its resize started
    @State private var statsResizeStart: CGFloat?

    private var theme: ThemeSpec { store.themeSpec }

    var body: some View {
        HStack(spacing: 0) {
            map
            statsResizeHandle
            statsColumn
                .frame(width: store.neuralStatsWidth)
        }
    }

    /// Draggable handle between the map and the stats column (220–460 px)
    private var statsResizeHandle: some View {
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
                        if statsResizeStart == nil { statsResizeStart = store.neuralStatsWidth }
                        guard let start = statsResizeStart else { return }
                        // The column sits on the right: dragging left widens it
                        store.neuralStatsWidth = min(max(start - value.translation.width, 220), 460)
                    }
                    .onEnded { _ in statsResizeStart = nil }
            )
    }

    // MARK: - Node model and layout

    private struct Node {
        let key: String
        var point: CGPoint
        let radius: CGFloat
        let label: String
        let emoji: String
        let activity: Double
        let running: Bool
        let isHub: Bool
        /// Provider brand color on agent nodes; nil for hub/workspace (uses the theme accent)
        var tint: Color? = nil
        /// Highlight for the selected workspace / focused terminal (outer ring)
        var selected: Bool = false
        /// Currently producing output (status dot: theme color)
        var executing: Bool = false
        /// Awaiting input/approval (status dot: yellow)
        var attention: Bool = false
    }

    private struct Edge {
        let from: String
        let to: String
        let activity: Double
        let phase: Double
    }

    private static func hubKey() -> String { "hub" }
    private static func key(forWorkspace id: UUID) -> String { "ws-\(id.uuidString)" }
    private static func key(forAgent sessionID: UUID) -> String { "ag-\(sessionID.uuidString)" }

    /// Computes the default circular layout and applies the user's moves.
    private func layout(in size: CGSize) -> (nodes: [Node], edges: [Edge]) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let workspaces = store.workspaces
        var nodes: [Node] = []
        var edges: [Edge] = []

        let wsRadius = min(size.width, size.height) * 0.22
        let agentRadius = min(size.width, size.height) * 0.40

        nodes.append(Node(
            key: Self.hubKey(),
            point: resolved(Self.hubKey(), fallback: center, in: size),
            radius: 26, label: "", emoji: "", activity: 0, running: true, isHub: true
        ))

        for (wi, workspace) in workspaces.enumerated() {
            let wsAngle = (Double(wi) / Double(max(1, workspaces.count))) * 2 * .pi - .pi / 2
            let wsKey = Self.key(forWorkspace: workspace.id)
            let wsDefault = CGPoint(
                x: center.x + cos(wsAngle) * wsRadius,
                y: center.y + sin(wsAngle) * wsRadius
            )
            let wsPoint = resolved(wsKey, fallback: wsDefault, in: size)

            let wsActivity = workspace.sessions
                .compactMap { TerminalRegistry.shared.existingController(for: $0.id)?.activityLevel }
                .max() ?? 0

            nodes.append(Node(
                key: wsKey, point: wsPoint, radius: 16,
                label: workspace.name, emoji: "🗂",
                activity: wsActivity, running: true, isHub: false,
                selected: workspace.id == store.selectedWorkspace?.id
            ))
            edges.append(Edge(
                from: Self.hubKey(), to: wsKey,
                activity: max(0.15, wsActivity), phase: Double(wi) * 1.7
            ))

            let count = workspace.sessions.count
            for (si, session) in workspace.sessions.enumerated() {
                let spread = 0.9
                let offset = count == 1 ? 0 : (Double(si) / Double(count - 1) - 0.5) * spread
                let angle = wsAngle + offset
                let agentKey = Self.key(forAgent: session.id)
                let agentDefault = CGPoint(
                    x: center.x + cos(angle) * agentRadius,
                    y: center.y + sin(angle) * agentRadius
                )
                let controller = TerminalRegistry.shared.existingController(for: session.id)
                let activity = controller?.activityLevel ?? 0

                nodes.append(Node(
                    key: agentKey,
                    point: resolved(agentKey, fallback: agentDefault, in: size),
                    radius: 14 + CGFloat(activity) * 6,
                    label: session.name, emoji: session.agent.emoji,
                    activity: activity,
                    running: controller?.agentRunning ?? false,
                    isHub: false,
                    tint: session.agent.provider.color,
                    selected: session.id == store.focusedSessionID,
                    executing: controller?.isExecuting ?? false,
                    attention: controller?.needsAttention ?? false
                ))
                edges.append(Edge(
                    from: wsKey, to: agentKey,
                    activity: max(0.1, activity),
                    phase: Double(wi) * 3.1 + Double(si) * 1.3
                ))
            }
        }
        return (nodes, edges)
    }

    /// Converts a moved node's normalized position to pixels; returns the default otherwise.
    private func resolved(_ key: String, fallback: CGPoint, in size: CGSize) -> CGPoint {
        guard let normalized = nodeOverrides[key] else { return fallback }
        return CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    // MARK: - Map

    private var map: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let (nodes, edges) = layout(in: size)
                    let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.key, $0) })

                    for edge in edges {
                        guard let from = nodeMap[edge.from], let to = nodeMap[edge.to] else { continue }
                        drawEdge(context: &context, from: from.point, to: to.point,
                                 activity: edge.activity, time: t, phase: edge.phase)
                    }
                    for node in nodes {
                        if node.isHub {
                            drawHub(context: &context, node: node, time: t)
                        } else {
                            drawNode(context: &context, node: node)
                        }
                    }
                }
            }
            .gesture(dragGesture(in: geo.size))
        }
        .background(theme.background)
    }

    /// Node interaction: click → select the workspace/terminal, drag → move it.
    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                if draggingKey == nil {
                    let (nodes, _) = layout(in: size)
                    guard let node = hitNode(at: value.startLocation, nodes: nodes) else { return }
                    draggingKey = node.key
                    // Preserve the grab point so the node does not jump to the cursor
                    dragOffset = CGSize(width: node.point.x - value.startLocation.x,
                                        height: node.point.y - value.startLocation.y)
                    hasDragged = false
                }
                guard let key = draggingKey else { return }
                let distance = hypot(value.translation.width, value.translation.height)
                // Movement below 3px is not a drag; keep treating it as a selecting click
                if hasDragged || distance > 3 {
                    hasDragged = true
                    let target = CGPoint(x: value.location.x + dragOffset.width,
                                         y: value.location.y + dragOffset.height)
                    nodeOverrides[key] = CGPoint(
                        x: min(max(target.x / size.width, 0.03), 0.97),
                        y: min(max(target.y / size.height, 0.05), 0.95)
                    )
                }
            }
            .onEnded { _ in
                if let key = draggingKey, !hasDragged {
                    select(nodeKey: key)
                }
                draggingKey = nil
                hasDragged = false
            }
    }

    /// Finds the pressed node, preferring the one drawn on top (last in the list).
    private func hitNode(at point: CGPoint, nodes: [Node]) -> Node? {
        for node in nodes.reversed() {
            let grabRadius = max(node.radius + 8, 20)
            let dx = point.x - node.point.x
            let dy = point.y - node.point.y
            if dx * dx + dy * dy <= grabRadius * grabRadius {
                return node
            }
        }
        return nil
    }

    /// Turns a clicked node into an app selection: a workspace node changes the selected
    /// workspace, an agent node changes both the workspace and the focused terminal.
    /// The "Terminal" button in the top bar now adds to this selection as well.
    private func select(nodeKey: String) {
        if nodeKey.hasPrefix("ws-"), let id = UUID(uuidString: String(nodeKey.dropFirst(3))) {
            guard store.selectedWorkspaceID != id else { return }
            store.selectedWorkspaceID = id
            store.focusedSessionID = store.selectedWorkspace?.sessions.first?.id
            store.maximizedSessionID = nil
            store.scheduleSave()
        } else if nodeKey.hasPrefix("ag-"), let id = UUID(uuidString: String(nodeKey.dropFirst(3))) {
            guard let workspace = store.workspaces.first(where: { ws in ws.sessions.contains { $0.id == id } })
            else { return }
            store.selectedWorkspaceID = workspace.id
            store.focusedSessionID = id
            store.scheduleSave()
        }
    }

    // MARK: - Drawing

    private func drawHub(context: inout GraphicsContext, node: Node, time: TimeInterval) {
        let accent = theme.accent
        let pulse = 1.0 + 0.06 * sin(time * 2.2)
        let r = node.radius * pulse
        let rect = CGRect(x: node.point.x - r, y: node.point.y - r, width: r * 2, height: r * 2)

        context.fill(Circle().path(in: rect.insetBy(dx: -14, dy: -14)),
                     with: .radialGradient(
                        Gradient(colors: [accent.opacity(0.35), .clear]),
                        center: node.point, startRadius: 4, endRadius: r + 34))
        context.fill(Circle().path(in: rect), with: .color(theme.panel))
        context.stroke(Circle().path(in: rect), with: .color(accent), lineWidth: 1.5)
        context.draw(
            Text("PUCKYTO").font(.system(size: 7, weight: .black)).foregroundColor(accent),
            at: node.point
        )
    }

    private func drawEdge(context: inout GraphicsContext, from: CGPoint, to: CGPoint,
                          activity: Double, time: TimeInterval, phase: Double) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(theme.accent.opacity(0.12 + activity * 0.25)), lineWidth: 1)

        // Signal particles: faster and brighter as activity rises
        let speed = 0.15 + activity * 0.9
        let particleCount = 3
        for p in 0..<particleCount {
            let progress = ((time * speed) + phase + Double(p) / Double(particleCount))
                .truncatingRemainder(dividingBy: 1.0)
            let x = from.x + (to.x - from.x) * progress
            let y = from.y + (to.y - from.y) * progress
            let r: CGFloat = 1.5 + CGFloat(activity) * 2.5
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            context.fill(Circle().path(in: rect),
                         with: .color(theme.accent.opacity(0.25 + activity * 0.75)))
        }
    }

    private func drawNode(context: inout GraphicsContext, node: Node) {
        let rect = CGRect(x: node.point.x - node.radius, y: node.point.y - node.radius,
                          width: node.radius * 2, height: node.radius * 2)
        let ringColor = node.tint ?? theme.accent

        if node.activity > 0.05 {
            context.fill(Circle().path(in: rect.insetBy(dx: -10, dy: -10)),
                         with: .radialGradient(
                            Gradient(colors: [ringColor.opacity(0.30 * node.activity + 0.08), .clear]),
                            center: node.point, startRadius: 2, endRadius: node.radius + 14))
        }

        let isDragging = draggingKey == node.key
        context.fill(Circle().path(in: rect), with: .color(theme.panel))
        context.stroke(
            Circle().path(in: rect),
            with: .color(node.running || isDragging ? ringColor : ringColor.opacity(0.45)),
            lineWidth: isDragging ? 2.2 : (node.running ? 1.8 : 1.2)
        )
        // Selected workspace / focused terminal: dashed outer ring
        if node.selected {
            context.stroke(
                Circle().path(in: rect.insetBy(dx: -4.5, dy: -4.5)),
                with: .color(theme.accent.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
            )
        }

        // Status dot (top right): yellow = awaiting approval, theme color = running
        if node.attention || node.executing {
            let dotColor: Color = node.attention ? .yellow : theme.accent
            let dr: CGFloat = 4
            let dx = node.point.x + node.radius * 0.72
            let dy = node.point.y - node.radius * 0.72
            let dotRect = CGRect(x: dx - dr, y: dy - dr, width: dr * 2, height: dr * 2)
            context.fill(Circle().path(in: dotRect), with: .color(dotColor))
            context.stroke(Circle().path(in: dotRect), with: .color(theme.panel), lineWidth: 1.5)
        }
        context.draw(Text(node.emoji).font(.system(size: node.radius * 0.85)), at: node.point)
        context.draw(
            Text(node.label).font(.system(size: 9, weight: .semibold)).foregroundColor(theme.textSecondary),
            at: CGPoint(x: node.point.x, y: node.point.y + node.radius + 10)
        )
    }

    // MARK: - Stats column

    private var statsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                PanelHeader(title: L("Ajan İstatistikleri"), systemImage: "chart.bar.fill")
                    .padding(.horizontal, -12)

                Text(L("💡 Düğüme tıkla: workspace/terminal seç · sürükle: taşı"))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                if !nodeOverrides.isEmpty {
                    Button {
                        nodeOverrides.removeAll()
                    } label: {
                        Label(L("Yerleşimi Sıfırla"), systemImage: "arrow.counterclockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ForEach(store.workspaces) { workspace in
                    Text(workspace.name.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)

                    ForEach(workspace.sessions) { session in
                        if let controller = TerminalRegistry.shared.existingController(for: session.id) {
                            NeuralStatCard(session: session, controller: controller, theme: theme)
                        } else {
                            NeuralStatPlaceholder(session: session, theme: theme)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(theme.panel.opacity(0.5))
    }
}

private struct NeuralStatCard: View {
    let session: TerminalSessionModel
    @ObservedObject var controller: TerminalController
    let theme: ThemeSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(session.agent.emoji) \(session.name)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                StatusDot(active: controller.isExecuting, color: theme.accent)
            }

            HStack {
                Chip(text: session.agent.provider.tag, tint: session.agent.provider.color)
                Chip(text: "\(controller.hasRealUsage ? "✓" : "≈") \(formatTokens(controller.displayTokens)) tok",
                     systemImage: "circle.hexagongrid", tint: theme.accent)
                Chip(text: formatBytes(controller.memoryBytes),
                     systemImage: "memorychip", tint: .secondary)
            }

            // Activity bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.background)
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: max(2, geo.size.width * CGFloat(controller.activityLevel)))
                }
            }
            .frame(height: 4)

            if !session.agent.task.isEmpty {
                Text(session.agent.task)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.panelBorder, lineWidth: 1))
    }
}

private struct NeuralStatPlaceholder: View {
    let session: TerminalSessionModel
    let theme: ThemeSpec

    var body: some View {
        HStack {
            Text("\(session.agent.emoji) \(session.name)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(L("kapalı"))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(theme.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
