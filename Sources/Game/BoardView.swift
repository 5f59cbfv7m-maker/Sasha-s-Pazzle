import CoreGraphics
import SwiftUI

/// Bridges native pointer events to the session, and owns viewport policy.
@MainActor
@Observable
final class BoardInputController: BoardEventHandling {
    var session: GameSession?
    var settings: AppSettings?
    var viewSize: CGSize = .zero
    var displayScale: CGFloat = 2
    private(set) var hoverPoint: CGPoint?

    @ObservationIgnored private var textureRefresh: Task<Void, Never>?

    func boardPointerDown(at point: CGPoint, isSecondary: Bool) -> Bool {
        guard let session, session.phase == .playing else { return false }
        let boardPoint = session.viewport.board(point)
        if isSecondary {
            if let piece = session.piece(at: boardPoint) { session.returnPieceToTray(piece) }
            return false
        }
        return session.beginDrag(at: boardPoint)
    }

    func boardPointerMoved(to point: CGPoint) {
        guard let session else { return }
        session.updateDrag(to: session.viewport.board(point))
    }

    func boardPointerUp(at point: CGPoint) {
        guard let session, let settings else { return }
        session.updateDrag(to: session.viewport.board(point))
        let outcome = session.endDrag(viewScale: session.viewport.scale, assist: settings.snapAssist)
        Feedback.shared.report(outcome, settings: settings)
    }

    func boardPointerCancelled() {
        session?.cancelDrag()
    }

    func boardPan(by delta: CGSize) {
        guard let session else { return }
        session.viewport = session.viewport.panned(by: delta)
            .clamped(content: session.tableRect, viewSize: viewSize)
    }

    func boardZoom(by factor: CGFloat, at point: CGPoint) {
        guard let session, factor.isFinite, factor > 0 else { return }
        session.viewport = session.viewport.zoomed(by: factor, around: point)
            .clamped(content: session.tableRect, viewSize: viewSize)
        scheduleTextureRefresh()
    }

    func boardHover(at point: CGPoint?) { hoverPoint = point }

    func fitBoard(padding: CGFloat = 40) {
        guard let session, viewSize.width > 1 else { return }
        session.viewport = .fitting(content: session.boardRect, in: viewSize, padding: padding)
        scheduleTextureRefresh()
    }

    func fitTable() {
        guard let session, viewSize.width > 1 else { return }
        session.viewport = .fitting(content: session.tableRect, in: viewSize, padding: 16)
        scheduleTextureRefresh()
    }

    func zoomStep(_ factor: CGFloat) {
        boardZoom(by: factor, at: CGPoint(x: viewSize.width / 2, y: viewSize.height / 2))
    }

    /// Re-cuts the piece bitmaps once the user stops zooming, so a magnified
    /// board stays crisp without re-rendering on every wheel tick.
    private func scheduleTextureRefresh() {
        textureRefresh?.cancel()
        textureRefresh = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, let session, let settings else { return }
            session.refreshTextures(displayScale: displayScale, settings: settings)
        }
    }
}

/// The puzzle surface: one `Canvas` for the pieces, one native view for input.
struct BoardView: View {
    let session: GameSession
    let settings: AppSettings
    let controller: BoardInputController

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                boardCanvas
                BoardEventView(handler: controller)
                    .accessibilityHidden(true)
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                let wasEmpty = controller.viewSize.width < 1
                controller.viewSize = size
                controller.displayScale = displayScale
                if wasEmpty { controller.fitBoard() }
            }
            .onAppear {
                controller.session = session
                controller.settings = settings
                controller.viewSize = proxy.size
                controller.displayScale = displayScale
                if session.viewport.scale == 1 { controller.fitBoard() }
            }
        }
        .background(BoardBackdrop())
        .accessibilityElement()
        .accessibilityLabel(Text("Puzzle board"))
        .accessibilityValue(Text("\(session.placedCount) of \(session.pieceCount) pieces placed"))
    }

    private var boardCanvas: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !session.needsAnimationTicks)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                draw(in: &context, size: size, now: timeline.date)
            }
        }
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize, now: Date) {
        let viewport = session.viewport
        let visible = CGRect(origin: .zero, size: size).insetBy(dx: -60, dy: -60)
        let textures = session.textures

        // Board plate: where the finished picture belongs.
        let plateRect = viewport.screen(session.boardRect)
        let corner = min(14, max(2, 10 * viewport.scale))
        let plate = Path(roundedRect: plateRect, cornerRadius: corner)
        context.fill(plate, with: .color(.black.opacity(0.10)))

        if settings.showGhostImage, let ghost = session.ghostImage {
            // Strong enough to guide, faint enough that a placed piece still
            // reads as clearly "on top of" the empty board.
            var ghostLayer = context
            ghostLayer.opacity = 0.24
            ghostLayer.clip(to: plate)
            ghostLayer.draw(ghost, in: plateRect)
        }
        context.stroke(plate, with: .color(.primary.opacity(0.22)), lineWidth: 1.5)

        guard !textures.images.isEmpty else { return }

        for groupID in session.drawOrder {
            guard let group = session.state.groups[groupID] else { continue }
            let isDragged = session.drag?.group == groupID

            if isDragged {
                // One shadow for the whole cluster reads as a single lifted object.
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: .black.opacity(0.42),
                                            radius: 10, x: 0, y: 7))
                    drawPieces(of: group, in: &layer, viewport: viewport,
                               visible: visible, textures: textures)
                }
            } else {
                drawPieces(of: group, in: &context, viewport: viewport,
                           visible: visible, textures: textures)
            }
        }

        drawFlashes(in: &context, viewport: viewport, visible: visible, textures: textures, now: now)
        drawHint(in: &context, viewport: viewport, now: now)
    }

    private func drawPieces(of group: PieceGroup, in context: inout GraphicsContext,
                            viewport: Viewport, visible: CGRect, textures: PieceTextureStore) {
        for piece in group.members {
            let index = Int(piece)
            guard index < textures.images.count, let image = textures.images[index] else { continue }
            let rect = viewport.screen(
                textures.localBounds[index].offsetBy(session.state.solvedOrigin(of: piece) + group.translation))
            guard rect.intersects(visible) else { continue }
            context.draw(image, in: rect)
        }
    }

    private func drawFlashes(in context: inout GraphicsContext, viewport: Viewport,
                             visible: CGRect, textures: PieceTextureStore, now: Date) {
        guard !session.flashes.isEmpty else { return }
        for (piece, start) in session.flashes {
            let progress = now.timeIntervalSince(start) / GameSession.flashDuration
            guard progress >= 0, progress < 1 else { continue }
            let index = Int(piece)
            guard index < textures.images.count, let image = textures.images[index],
                  let group = session.state.group(of: piece) else { continue }
            let rect = viewport.screen(
                textures.localBounds[index].offsetBy(session.state.solvedOrigin(of: piece) + group.translation))
            guard rect.intersects(visible) else { continue }
            var glow = context
            glow.blendMode = .plusLighter
            glow.opacity = (1 - progress) * 0.9
            glow.addFilter(.colorMultiply(Color(red: 0.25, green: 1.0, blue: 0.45)))
            glow.draw(image, in: rect)
        }
    }

    private func drawHint(in context: inout GraphicsContext, viewport: Viewport, now: Date) {
        guard let hint = session.hint, now < hint.expires else { return }
        let piece = hint.piece
        let origin = session.state.solvedOrigin(of: piece)
        let transform = CGAffineTransform(translationX: origin.x, y: origin.y)
            .concatenating(CGAffineTransform(scaleX: viewport.scale, y: viewport.scale))
            .concatenating(CGAffineTransform(translationX: viewport.offset.width,
                                             y: viewport.offset.height))
        let outline = Path(session.path(for: Int(piece))).applying(transform)
        let pulse = 0.55 + 0.45 * sin(now.timeIntervalSinceReferenceDate * 6)

        context.fill(outline, with: .color(.accentColor.opacity(0.22 * pulse)))
        context.stroke(outline, with: .color(.accentColor.opacity(0.55 + 0.45 * pulse)),
                       style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))

        // Trace from the piece's current spot to where it belongs.
        if let group = session.state.group(of: piece) {
            let from = viewport.screen(origin + group.translation
                + CGPoint(x: session.geometry.cellSize.width / 2,
                          y: session.geometry.cellSize.height / 2))
            let to = viewport.screen(origin + CGPoint(x: session.geometry.cellSize.width / 2,
                                                      y: session.geometry.cellSize.height / 2))
            var line = Path()
            line.move(to: from)
            line.addLine(to: to)
            context.stroke(line, with: .color(.accentColor.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
        }
    }
}

/// Subtle felt-like table behind the puzzle.
private struct BoardBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(colors: scheme == .dark
                       ? [Color(white: 0.10), Color(white: 0.055)]
                       : [Color(white: 0.92), Color(white: 0.84)],
                       startPoint: .top, endPoint: .bottom)
        .overlay(alignment: .center) {
            RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.05 : 0.5), .clear],
                           center: .center, startRadius: 0, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}
