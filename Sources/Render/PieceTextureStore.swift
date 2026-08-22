import CoreGraphics
import Foundation
import Observation
import SwiftUI

nonisolated extension CGContext {
    /// Draws an image into a rect of a y-flipped (top-left origin) context.
    ///
    /// Board space runs downward like a screen; CoreGraphics contexts run upward.
    /// The local double flip keeps images upright without inverting the geometry.
    func drawFlipped(_ image: CGImage, in rect: CGRect) {
        saveGState()
        translateBy(x: rect.minX, y: rect.maxY)
        scaleBy(x: 1, y: -1)
        draw(image, in: CGRect(origin: .zero, size: rect.size))
        restoreGState()
    }
}

/// Pre-rendered bitmap for every piece, including its bevel.
///
/// This is the single most important performance decision in the app. Clipping
/// 800 Bézier outlines against a photograph *every frame* is hopeless; doing it
/// **once** per piece and then blitting cached bitmaps turns the draw loop into
/// a few hundred textured rectangles, which Core Graphics handles comfortably at
/// display refresh rate.
///
/// Work is chunked so progress can be reported and cancelled, and each chunk is
/// spread across all cores.
@Observable
final class PieceTextureStore {

    private(set) var textures: [CGImage?] = []
    /// SwiftUI wrappers created once per texture. Building them inside the draw
    /// loop would allocate 800 times per frame.
    private(set) var images: [Image?] = []
    /// Outline bounds of each piece relative to its own cell origin, in board units.
    private(set) var localBounds: [CGRect] = []
    private(set) var pixelScale: CGFloat = 1
    private(set) var progress: Double = 0
    private(set) var isReady = false

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Texture memory ceiling. Beyond this the pixel scale is reduced rather
    /// than risking a memory-pressure termination on a huge puzzle.
    static let pixelBudget: Double = 90_000_000

    deinit { task?.cancel() }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func texture(for piece: Int) -> CGImage? {
        piece >= 0 && piece < textures.count ? textures[piece] : nil
    }

    /// Board-space rectangle a piece's texture covers when the piece is solved.
    func solvedRect(for piece: Int, geometry: PuzzleGeometry) -> CGRect {
        guard piece < localBounds.count else { return geometry.cellFrame(of: piece) }
        return localBounds[piece].offsetBy(geometry.solvedOrigin(of: piece))
    }

    /// Largest pixel scale that fits the budget for this geometry.
    static func affordableScale(for geometry: PuzzleGeometry, desired: CGFloat) -> CGFloat {
        let cell = geometry.cellSize
        let overhang = geometry.maximumOverhang * 2
        let area = Double((cell.width + overhang) * (cell.height + overhang)) * Double(geometry.pieceCount)
        guard area > 0 else { return desired }
        let maximum = (pixelBudget / area).squareRoot()
        return clamp(min(desired, CGFloat(maximum)), 0.35, 3.5)
    }

    func rebuild(geometry: PuzzleGeometry, source: RenderedImage,
                 pixelScale desired: CGFloat, outlines: Bool) {
        let scale = Self.affordableScale(for: geometry, desired: desired)
        // Re-rendering for a change smaller than 25% is not worth the work.
        if isReady, abs(scale - pixelScale) / max(pixelScale, 0.001) < 0.25,
           textures.count == geometry.pieceCount { return }

        task?.cancel()
        let count = geometry.pieceCount
        if textures.count != count {
            textures = Array(repeating: nil, count: count)
            images = Array(repeating: nil, count: count)
        }
        localBounds = (0..<count).map { geometry.localBounds(of: $0) }
        pixelScale = scale
        progress = 0
        isReady = false

        task = Task { [geometry, source] in
            let chunkSize = max(16, count / 24)
            var index = 0
            while index < count {
                if Task.isCancelled { return }
                let range = Array(index..<min(index + chunkSize, count))
                let rendered = await Task.detached(priority: .userInitiated) {
                    UncheckedSendable(Self.render(pieces: range, geometry: geometry, source: source,
                                                  pixelScale: scale, outlines: outlines))
                }.value
                if Task.isCancelled { return }
                for (piece, image) in rendered.value where piece < self.textures.count {
                    self.textures[piece] = image
                    self.images[piece] = Image(decorative: image, scale: 1)
                }
                index += range.count
                self.progress = Double(index) / Double(count)
            }
            self.isReady = true
        }
    }

    // MARK: - Rendering

    nonisolated static func render(pieces: [Int], geometry: PuzzleGeometry,
                                           source: RenderedImage, pixelScale: CGFloat,
                                           outlines: Bool) -> [Int: CGImage] {
        var results = [CGImage?](repeating: nil, count: pieces.count)
        results.withUnsafeMutableBufferPointer { buffer in
            let out = UncheckedSendable(buffer)
            DispatchQueue.concurrentPerform(iterations: pieces.count) { slot in
                out.value[slot] = renderPiece(pieces[slot], geometry: geometry, source: source,
                                              pixelScale: pixelScale, outlines: outlines)
            }
        }
        var map: [Int: CGImage] = [:]
        for (slot, piece) in pieces.enumerated() {
            if let image = results[slot] { map[piece] = image }
        }
        return map
    }

    nonisolated static func renderPiece(_ piece: Int, geometry: PuzzleGeometry,
                                                source: RenderedImage, pixelScale: CGFloat,
                                                outlines: Bool) -> CGImage? {
        let bounds = geometry.localBounds(of: piece)
        let origin = geometry.solvedOrigin(of: piece)
        let pixelSize = CGSize(width: (bounds.width * pixelScale).rounded(.up),
                               height: (bounds.height * pixelScale).rounded(.up))
        guard pixelSize.width >= 2, pixelSize.height >= 2,
              let context = ArtToolkit.makeContext(size: pixelSize) else { return nil }

        // Board units with y running downward, origin at the piece's cell corner.
        context.translateBy(x: 0, y: pixelSize.height)
        context.scaleBy(x: pixelScale, y: -pixelScale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)

        let path = geometry.localPath(of: piece)
        let pixelsPerUnit = CGFloat(source.width) / geometry.boardSize.width

        context.saveGState()
        context.addPath(path)
        context.clip()

        // Photo fragment: crop the source instead of drawing the whole image
        // under a clip — cropping a CGImage is a cheap view, drawing is not.
        let boardRect = bounds.offsetBy(origin)
        let desired = CGRect(x: boardRect.minX * pixelsPerUnit, y: boardRect.minY * pixelsPerUnit,
                             width: boardRect.width * pixelsPerUnit,
                             height: boardRect.height * pixelsPerUnit)
        let full = CGRect(x: 0, y: 0, width: CGFloat(source.width), height: CGFloat(source.height))
        let sourceRect = desired.intersection(full).integral
        if sourceRect.width >= 1, sourceRect.height >= 1,
           let fragment = source.cgImage.cropping(to: sourceRect) {
            let destination = CGRect(x: sourceRect.minX / pixelsPerUnit - origin.x,
                                     y: sourceRect.minY / pixelsPerUnit - origin.y,
                                     width: sourceRect.width / pixelsPerUnit,
                                     height: sourceRect.height / pixelsPerUnit)
            context.interpolationQuality = .high
            context.drawFlipped(fragment, in: destination)
        } else {
            context.setFillColor(CGColor(gray: 0.5, alpha: 1))
            context.fill(bounds)
        }

        // Bevel: light from the top-left, shadow to the bottom-right, both
        // clipped to the outline so the piece reads as a cut cardboard shape.
        let depth = max(0.45, geometry.cellSize.minimumSide * 0.034)
        context.setLineJoin(.round)
        context.setLineWidth(depth * 1.7)
        for (dx, dy, color) in [(-depth * 0.5, -depth * 0.5, CGColor(gray: 1, alpha: 0.36)),
                                (depth * 0.5, depth * 0.5, CGColor(gray: 0, alpha: 0.32))] {
            context.saveGState()
            context.translateBy(x: dx, y: dy)
            context.addPath(path)
            context.setStrokeColor(color)
            context.strokePath()
            context.restoreGState()
        }
        // Inner rim: keeps two adjacent solved pieces visually separated.
        context.addPath(path)
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.22))
        context.setLineWidth(depth * 0.7)
        context.strokePath()
        context.restoreGState()

        if outlines {
            context.addPath(path)
            context.setStrokeColor(CGColor(gray: 0.08, alpha: 0.38))
            context.setLineWidth(max(0.35, depth * 0.32))
            context.strokePath()
        }
        return context.makeImage()
    }
}
