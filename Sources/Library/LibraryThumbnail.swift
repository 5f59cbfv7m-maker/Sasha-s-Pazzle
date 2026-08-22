import SwiftUI

/// Lazily produced preview of a library picture.
///
/// Generated art is rendered on demand at thumbnail resolution — roughly ten
/// milliseconds — and cached, so scrolling 580 cells never blocks the main thread.
struct LibraryThumbnail: View {
    let item: LibraryItem
    var longSide: Int = 420

    @State private var image: Image?

    var body: some View {
        // `Color.clear` is the only element that takes part in layout: the
        // picture lives in an overlay so a square artwork can never stretch a
        // 3:2 card and break the surrounding grid.
        Color.clear
            .overlay {
                if let image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .background(.quaternary)
            .clipped()
            .contentShape(Rectangle())
            .task(id: item.id) { await load() }
    }

    private func load() async {
        let request = ImageStore.Request(item: item, aspect: .original, longSide: longSide)
        guard let rendered = await ImageStore.shared.image(request) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            image = Image(decorative: rendered.cgImage, scale: 1)
        }
    }
}
