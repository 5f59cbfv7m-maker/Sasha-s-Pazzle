import SwiftUI

/// The panel of pieces that have not been put on the table yet.
///
/// A lazy grid is essential here: a nightmare-mode puzzle puts 800 cells in this
/// view, and only the couple of dozen on screen are ever materialised.
struct TrayView: View {
    let session: GameSession
    let placement: TrayPlacement
    let onChanged: (Int32, CGPoint) -> Void
    let onEnded: (Int32, CGPoint) -> Void

    private let cellSize: CGFloat = 62

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if session.state.trayOrder.isEmpty {
                emptyState
            } else {
                pieceGrid
            }
        }
        .background(.background.secondary)
    }

    private var header: some View {
        HStack {
            Text("Pieces")
                .font(.headline)
            Spacer()
            Text("\(session.state.trayOrder.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("All pieces are on the table")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var pieceGrid: some View {
        let columns = [GridItem(.adaptive(minimum: cellSize, maximum: cellSize), spacing: 6)]
        let rows = [GridItem(.adaptive(minimum: cellSize, maximum: cellSize), spacing: 6)]

        if placement == .trailing {
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, spacing: 6) { cells }
                    .padding(8)
            }
        } else {
            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, spacing: 6) { cells }
                    .padding(8)
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.5))
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(3)
            } else {
                Image(systemName: "puzzlepiece")
                    .foregroundStyle(.tertiary)
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
