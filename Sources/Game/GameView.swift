import SwiftUI

/// Where the unplaced pieces live for the current window shape.
enum TrayPlacement { case trailing, bottom }

/// The playing screen: board, tray, HUD and overlays.
struct GameView: View {
    let session: GameSession

    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var controller: BoardInputController { model.boardController }
    @State private var trayDrag: TrayDrag?
    @State private var boardFrame: CGRect = .zero
    @State private var showOriginal = false
    @State private var didLoad = false

    struct TrayDrag: Equatable {
        var piece: Int32
        var location: CGPoint
    }

    var body: some View {
        GeometryReader { proxy in
            let placement: TrayPlacement = trayPlacement(for: proxy.size)

            ZStack {
                Group {
                    if placement == .trailing {
                        HStack(spacing: 0) {
                            board
                            Divider()
                            tray(placement: placement)
                                .frame(width: trayThickness(for: proxy.size))
                        }
                    } else {
                        VStack(spacing: 0) {
                            board
                            Divider()
                            tray(placement: placement)
                                .frame(height: trayThickness(for: proxy.size))
                        }
                    }
                }

                overlays

                if let trayDrag, let image = session.textures.images[safe: Int(trayDrag.piece)] ?? nil {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: draggedPieceSize, height: draggedPieceSize)
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                        .position(trayDrag.location)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .coordinateSpace(.named("game"))
        }
        .navigationTitle(session.item.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .task(id: session.id) {
            guard !didLoad else { return }
            didLoad = true
            await session.load(displayScale: displayScale, settings: settings,
                               isNewGame: session.placedCount == 0 && session.elapsed == 0)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.handleBackground() }
        }
        .onDisappear { session.saveNow() }
        .sheet(isPresented: $showOriginal) { OriginalImageSheet(session: session) }
    }

    // MARK: - Pieces

    private var board: some View {
        BoardView(session: session, settings: settings, controller: controller)
            .overlay {
                GeometryReader { proxy in
                    Color.clear.onGeometryChange(for: CGRect.self) {
                        $0.frame(in: .named("game"))
                    } action: { boardFrame = $0 }
                }
            }
            .overlay(alignment: .bottomLeading) { statusBar.padding(12) }
            .overlay(alignment: .bottomTrailing) { zoomControls.padding(12) }
    }

    private func tray(placement: TrayPlacement) -> some View {
        TrayView(session: session, placement: placement) { piece, location in
            trayDrag = TrayDrag(piece: piece, location: location)
        } onEnded: { piece, location in
            trayDrag = nil
            guard boardFrame.contains(location) else { return }
            let boardPoint = session.viewport.board(CGPoint(x: location.x - boardFrame.minX,
                                                            y: location.y - boardFrame.minY))
            let outcome = session.placePieceFromTray(piece, at: boardPoint,
                                                     viewScale: session.viewport.scale,
                                                     assist: settings.snapAssist)
            Feedback.shared.report(outcome, settings: settings)
        }
    }

    /// Clock and progress. `ViewThatFits` drops to a stacked form rather than
    /// being clipped when the board is only a phone wide.
    private var statusBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                clockLabel
                Divider().frame(height: 14)
                progressLabel
                solveProgress
            }
            VStack(alignment: .leading, spacing: 2) {
                clockLabel
                progressLabel
            }
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.primary.opacity(0.08)))
    }

    private var clockLabel: some View {
        Label(TimeFormatting.clock(session.elapsed), systemImage: "clock")
            .monospacedDigit()
            .accessibilityLabel(Text("Elapsed time"))
            .accessibilityValue(Text(TimeFormatting.spoken(session.elapsed)))
    }

    /// Fraction of pieces that are joined to at least one neighbour — a truer
    /// measure of progress than "taken out of the tray".
    private var solveProgress: some View {
        ProgressView(value: session.completion)
            .progressViewStyle(.linear)
            .frame(width: 72)
            .accessibilityLabel(Text("Pieces placed"))
    }

    private var progressLabel: some View {
        Label("\(session.placedCount)/\(session.pieceCount)", systemImage: "puzzlepiece")
            .monospacedDigit()
            .accessibilityLabel(Text("Pieces placed"))
    }

    private var zoomControls: some View {
        VStack(spacing: 6) {
            Button { controller.zoomStep(1.25) } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Zoom in"))
            Button { controller.zoomStep(0.8) } label: { Image(systemName: "minus") }
                .accessibilityLabel(Text("Zoom out"))
            Divider().frame(width: 18)
            Button { controller.fitBoard() } label: { Image(systemName: "rectangle.center.inset.filled") }
                .accessibilityLabel(Text("Fit board"))
            Button { controller.fitTable() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .accessibilityLabel(Text("Fit table"))
        }
        .buttonStyle(.borderless)
        .font(.system(size: 13, weight: .semibold))
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.primary.opacity(0.08)))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // The size-class branch lives inside the `ViewBuilder`, not the
        // `ToolbarContentBuilder`: a conditional at the toolbar-content level
        // silently produces no items on a compact width.
        ToolbarItemGroup(placement: .primaryAction) {
            #if os(iOS)
            if sizeClass == .compact {
                Menu {
                    actionButtons
                    Divider()
                    undoRedoButtons
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            } else {
                actionButtons
                undoRedoButtons
            }
            #else
            actionButtons
            #endif
            pauseButton
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button { session.requestHint() } label: { Label("Hint", systemImage: "lightbulb") }
            .disabled(session.phase != .playing)
        Button { showOriginal = true } label: { Label("Show Original", systemImage: "photo") }
        Button { session.scatterTray() } label: { Label("Scatter Pieces", systemImage: "shuffle") }
            .disabled(session.phase != .playing || session.state.trayOrder.isEmpty)
    }

    @ViewBuilder
    private var undoRedoButtons: some View {
        Button { session.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
            .disabled(!session.canUndo)
        Button { session.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
            .disabled(!session.canRedo)
    }

    private var pauseButton: some View {
        Button {
            session.phase == .paused ? session.resume() : session.pause()
        } label: {
            Label(session.phase == .paused ? "Resume" : "Pause",
                  systemImage: session.phase == .paused ? "play.fill" : "pause.fill")
        }
        .disabled(session.phase == .completed)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var overlays: some View {
        if !session.isLoaded || session.textures.progress < 1 {
            LoadingOverlay(session: session)
        }
        if let failure = session.loadFailure {
            ErrorOverlay(message: failure) { model.showLibrary() }
        }
        if session.phase == .paused, session.loadFailure == nil {
            PauseOverlay(session: session)
        }
        if session.phase == .completed {
            CompletionOverlay(session: session)
        }
    }

    // MARK: - Layout policy

    private func trayPlacement(for size: CGSize) -> TrayPlacement {
        #if os(macOS)
        size.width >= 720 ? .trailing : .bottom
        #else
        size.width > size.height && size.width >= 700 ? .trailing : .bottom
        #endif
    }

    private func trayThickness(for size: CGSize) -> CGFloat {
        #if os(macOS)
        clamp(size.width * 0.19, 190, 320)
        #else
        size.width > size.height ? clamp(size.width * 0.2, 170, 300) : clamp(size.height * 0.2, 130, 220)
        #endif
    }

    private var draggedPieceSize: CGFloat {
        max(44, session.geometry.cellSize.minimumSide * session.viewport.scale * 1.6)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum TimeFormatting {
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func spoken(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: max(0, interval)) ?? clock(interval)
    }
}
