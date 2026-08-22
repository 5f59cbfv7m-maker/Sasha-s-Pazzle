import CoreGraphics
import Foundation

/// Maps board units to screen points.
///
/// Keeping the transform in one small value type is what makes window resizing
/// and device rotation harmless: the puzzle's logical coordinates never change,
/// only this mapping does.
nonisolated struct Viewport: Sendable, Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    static let minimumScale: CGFloat = 0.08
    static let maximumScale: CGFloat = 8

    func screen(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale + offset.width, y: point.y * scale + offset.height)
    }

    func board(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - offset.width) / scale, y: (point.y - offset.height) / scale)
    }

    func screen(_ rect: CGRect) -> CGRect {
        CGRect(origin: screen(rect.origin), size: CGSize(width: rect.width * scale, height: rect.height * scale))
    }

    /// The board-space region currently visible in a view of `size`.
    func visibleBoardRect(viewSize: CGSize) -> CGRect {
        CGRect(origin: board(.zero),
               size: CGSize(width: viewSize.width / scale, height: viewSize.height / scale))
    }

    /// Fits `content` inside `viewSize` with a margin, centred.
    static func fitting(content: CGRect, in viewSize: CGSize, padding: CGFloat = 24) -> Viewport {
        guard content.width > 0, content.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return Viewport()
        }
        let available = CGSize(width: max(1, viewSize.width - padding * 2),
                               height: max(1, viewSize.height - padding * 2))
        let scale = clamp(min(available.width / content.width, available.height / content.height),
                          minimumScale, maximumScale)
        let offset = CGSize(width: viewSize.width / 2 - content.center.x * scale,
                            height: viewSize.height / 2 - content.center.y * scale)
        return Viewport(scale: scale, offset: offset)
    }

    /// Zooms around a fixed screen point, so the content under the cursor or the
    /// pinch centre stays put.
    func zoomed(by factor: CGFloat, around anchor: CGPoint) -> Viewport {
        let newScale = clamp(scale * factor, Self.minimumScale, Self.maximumScale)
        let effective = newScale / scale
        return Viewport(scale: newScale,
                        offset: CGSize(width: anchor.x - (anchor.x - offset.width) * effective,
                                       height: anchor.y - (anchor.y - offset.height) * effective))
    }

    func panned(by delta: CGSize) -> Viewport {
        Viewport(scale: scale, offset: CGSize(width: offset.width + delta.width,
                                              height: offset.height + delta.height))
    }

    /// Keeps the content from being dragged entirely off screen.
    func clamped(content: CGRect, viewSize: CGSize) -> Viewport {
        let frame = screen(content)
        let slackX = max(viewSize.width * 0.35, 80)
        let slackY = max(viewSize.height * 0.35, 80)
        var result = self
        if frame.maxX < slackX { result.offset.width += slackX - frame.maxX }
        if frame.minX > viewSize.width - slackX { result.offset.width -= frame.minX - (viewSize.width - slackX) }
        if frame.maxY < slackY { result.offset.height += slackY - frame.maxY }
        if frame.minY > viewSize.height - slackY { result.offset.height -= frame.minY - (viewSize.height - slackY) }
        return result
    }
}
