import SwiftUI

/// The panel of pieces that have not been put on the table yet.
///
/// A lazy grid is essential here: a nightmare-mode puzzle puts 800 cells in this
/// view, and only the couple of dozen on screen are ever materialised.
struct TrayView: View {
    let session: GameSession
    let placement: TrayPlacement
    /// Footer action; `nil` hides the footer (the phone keeps it in the menu).
    var onScatter: (() -> Void)?
    let onChanged: (Int32, CGPoint) -> Void
    let onEnded: (Int32, CGPoint) -> Void

    private var cellSize: CGFloat { placement == .trailing ? 74 : 63 }

    var body: some View {
        VStack(spacing: 0) {
            header
            if session.state.trayOrder.isEmpty {
                emptyState
            } else {
                pieceGrid
            }
            if let onScatter, placement == .trailing {
                Theme.hairline.frame(height: 1)
                PillButton(title: "Scatter on the table", style: .secondary, size: 16, expand: true, action: onScatter)
                    .disabled(session.phase != .playing || session.state.trayOrder.isEmpty)
                    .padding(EdgeInsets(top: 14, leading: 20, bottom: 20, trailing: 20))
            }
        }
        .background(Theme.surface)
    }

    private var header: some View {
        HStack {
            Text("Pieces")
                .font(Theme.display(placement == .trailing ? 19 : 17))
            Spacer()
            Text("\(session.state.trayOrder.count)")
                .font(Theme.body(14, .bold).monospacedDigit())
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Theme.card, in: Capsule())
        }
        .padding(.horizontal, placement == .trailing ? 20 : 16)
        .padding(.top, placement == .trailing ? 18 : 12)
        .padding(.bottom, placement == .trailing ? 12 : 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.onSageTint)
                .frame(width: 64, height: 64)
                .background(Theme.sageTint, in: Circle())
            Text("All pieces are on the table")
                .font(Theme.body(15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var pieceGrid: some View {
        let columns = [GridItem(.adaptive(minimum: cellSize, maximum: cellSize), spacing: 10)]
        let rows = [GridItem(.adaptive(minimum: cellSize, maximum: cellSize), spacing: 10)]

        if placement == .trailing {
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, spacing: 10) { cells }
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
            }
        } else {
            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, spacing: 10) { cells }
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
            }
        }
    }

    @ViewBuilder
    private var cells: some View {
        ForEach(session.state.trayOrder, id: \.self) { piece in
            TrayCell(image: session.textures.images[safe: Int(piece)] ?? nil, size: cellSize)
                .trayDragGesture(piece: piece, onChanged: onChanged, onEnded: onEnded)
                .accessibilityLabel(Text("Puzzle piece"))
                .accessibilityHint(Text("Drag onto the board"))
        }
    }
}

private struct TrayCell: View {
    let image: Image?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
            } else {
                Image(systemName: "puzzlepiece")
                    .foregroundStyle(Theme.track)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
    }
}

private extension View {
    /// Mouse drags start immediately; touch requires a short press so the tray
    /// can still be scrolled with a finger.
    func trayDragGesture(piece: Int32,
                         onChanged: @escaping (Int32, CGPoint) -> Void,
                         onEnded: @escaping (Int32, CGPoint) -> Void) -> some View {
        #if os(macOS)
        highPriorityGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("game"))
                .onChanged { onChanged(piece, $0.location) }
                .onEnded { onEnded(piece, $0.location) }
        )
        #else
        gesture(
            LongPressGesture(minimumDuration: 0.16)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("game")))
                .onChanged { value in
                    if case let .second(_, drag?) = value { onChanged(piece, drag.location) }
                }
                .onEnded { value in
                    if case let .second(_, drag?) = value { onEnded(piece, drag.location) }
                }
        )
        #endif
    }
}
