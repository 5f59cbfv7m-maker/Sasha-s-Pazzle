import CoreGraphics
import Foundation
import simd

/// Composable drawing primitives shared by every artwork family.
///
/// Each generated picture is a short recipe of these calls, which is what keeps
/// 500+ distinct images down to a few hundred lines of generator code.
nonisolated enum ArtToolkit {

    // MARK: - Contexts and rasters

    static func makeContext(size: CGSize) -> CGContext? {
        let width = max(1, Int(size.width.rounded())), height = max(1, Int(size.height.rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let context = CGContext(data: nil, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                    | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.interpolationQuality = .high
        return context
    }

    /// Turns a scalar field into an image through a colour ramp.
    /// `alphaCurve` lets a layer fade out where the field is weak.
    static func image(from field: ScalarField, palette: Palette,
                      alphaCurve: (@Sendable (Float) -> Float)? = nil) -> CGImage? {
        let width = field.width, height = field.height
        // 1024-entry ramp: sampling the stop list per pixel dominated the cost.
        let rampSize = 1024
        var ramp = [SIMD3<Double>](repeating: .zero, count: rampSize)
        for index in 0..<rampSize {
            ramp[index] = palette.color(at: Double(index) / Double(rampSize - 1))
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBufferPointer { buffer in
            let out = UncheckedSendable(buffer)
            field.samples.withUnsafeBufferPointer { source in
                let input = UncheckedSendable(source)
                let lut = UncheckedSendable(ramp)
                DispatchQueue.concurrentPerform(iterations: height) { row in
                    for column in 0..<width {
                        let index = row * width + column
                        let sample = input.value[index]
                        let rgb = lut.value[Int(clamp(sample, 0, 1) * Float(rampSize - 1))]
                        let alpha = alphaCurve.map { clamp($0(sample), 0, 1) } ?? 1
                        let a = Double(alpha)
                        // Premultiplied BGRA to match `makeContext`.
                        out.value[index * 4 + 0] = UInt8(clamp(rgb.z * a, 0, 1) * 255)
                        out.value[index * 4 + 1] = UInt8(clamp(rgb.y * a, 0, 1) * 255)
                        out.value[index * 4 + 2] = UInt8(clamp(rgb.x * a, 0, 1) * 255)
                        out.value[index * 4 + 3] = UInt8(a * 255)
                    }
                }
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                                                | CGBitmapInfo.byteOrder32Little.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Renders a noise layer at reduced resolution and upsamples it into `rect`.
    static func drawField(_ field: ScalarField, palette: Palette, in context: CGContext,
                          rect: CGRect, blend: CGBlendMode = .normal, alpha: CGFloat = 1,
                          alphaCurve: (@Sendable (Float) -> Float)? = nil) {
        guard let image = image(from: field, palette: palette, alphaCurve: alphaCurve) else { return }
        context.saveGState()
        context.setBlendMode(blend)
        context.setAlpha(alpha)
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        context.restoreGState()
    }

    // MARK: - Backgrounds

    static func linearGradient(in context: CGContext, rect: CGRect, palette: Palette,
                               from start: CGPoint? = nil, to end: CGPoint? = nil) {
        let colors = stride(from: 0.0, through: 1.0, by: 0.05).map { palette.cgColor(at: $0) }
        let locations = stride(from: 0.0, through: 1.0, by: 0.05).map { CGFloat($0) }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)
        else { return }
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(gradient,
                                   start: start ?? CGPoint(x: rect.midX, y: rect.maxY),
                                   end: end ?? CGPoint(x: rect.midX, y: rect.minY),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    static func radialGlow(in context: CGContext, center: CGPoint, radius: CGFloat,
                           color: CGColor, blend: CGBlendMode = .plusLighter) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        let clear = color.copy(alpha: 0) ?? color
        guard let gradient = CGGradient(colorsSpace: space, colors: [color, clear] as CFArray,
                                        locations: [0, 1]) else { return }
        context.saveGState()
        context.setBlendMode(blend)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: radius, options: [])
        context.restoreGState()
    }

    static func vignette(in context: CGContext, rect: CGRect, strength: CGFloat = 0.45) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let gradient = CGGradient(colorsSpace: space,
                                        colors: [CGColor(gray: 0, alpha: 0),
                                                 CGColor(gray: 0, alpha: strength)] as CFArray,
                                        locations: [0.45, 1]) else { return }
        context.saveGState()
        context.clip(to: rect)
        let radius = max(rect.width, rect.height) * 0.78
        context.drawRadialGradient(gradient, startCenter: rect.center, startRadius: 0,
                                   endCenter: rect.center, endRadius: radius, options: [])
        context.restoreGState()
    }

    // MARK: - Detail passes

    /// Scatters small bright points. Also the star field for space scenes.
    static func speckle(in context: CGContext, rect: CGRect, rng: inout SplitMix64,
                        count: Int, maxRadius: CGFloat, palette: Palette,
                        blend: CGBlendMode = .plusLighter, alphaRange: ClosedRange<CGFloat> = 0.2...0.9) {
        context.saveGState()
        context.setBlendMode(blend)
        for _ in 0..<count {
            let point = rng.point(in: rect)
            let radius = rng.cg(maxRadius * 0.18...maxRadius)
            let color = palette.cgColor(at: rng.double(in: 0...1), alpha: rng.cg(alphaRange))
            context.setFillColor(color)
            context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
                                           width: radius * 2, height: radius * 2))
        }
        context.restoreGState()
    }

    /// The mandatory final pass on every artwork.
    ///
    /// An 800-piece puzzle is only solvable if neighbouring pieces look
    /// *different*, so every image gets structured high-frequency texture:
    /// short tinted strokes at several scales plus a fine grain. Smooth
    /// gradients alone would make the hard modes impossible.
    static func detailPass(in context: CGContext, rect: CGRect, rng: inout SplitMix64,
                           palette: Palette, intensity: CGFloat = 1) {
        let area = rect.width * rect.height
        let strokes = Int(area / 5200 * Double(intensity))
        context.saveGState()
        context.setLineCap(.round)
        for _ in 0..<max(200, strokes) {
            let origin = rng.point(in: rect)
            let length = rng.cg(rect.width * 0.002...rect.width * 0.02)
            let angle = rng.cg(0...(.pi * 2))
            let width = rng.cg(rect.width * 0.0008...rect.width * 0.0034)
            let lighten = rng.chance(0.5)
            context.setBlendMode(lighten ? .softLight : .overlay)
            context.setStrokeColor(palette.cgColor(at: rng.double(in: 0...1),
                                                   alpha: rng.cg(0.05...0.24) * intensity))
            context.setLineWidth(width)
            context.move(to: origin)
            context.addLine(to: CGPoint(x: origin.x + cos(angle) * length,
                                        y: origin.y + sin(angle) * length))
            context.strokePath()
        }
        context.restoreGState()

        // Fine grain keeps flat regions from looking plastic.
        let grainNoise = PerlinNoise(seed: rng.next())
        let grain = ScalarField.generate(width: 220, height: 220) { x, y in
            grainNoise.fbm(x * 110, y * 110, octaves: 2) * 0.5 + 0.5
        }
        let grey = Palette(hex: [0x000000, 0xFFFFFF])
        drawField(grain, palette: grey, in: context, rect: rect, blend: .softLight,
                  alpha: 0.16 * intensity)
    }

    // MARK: - Shapes

    /// A ridge silhouette rising from the bottom of the canvas.
    ///
    /// Drawing uses CoreGraphics' native bottom-left origin: `+y` is up, and
    /// palette position `0` maps to the top of the canvas.
    static func ridgeSilhouette(in context: CGContext, rect: CGRect, baseline: CGFloat,
                                amplitude: CGFloat, noise: PerlinNoise, frequency: Double,
                                octaves: Int, color: CGColor, sharpness: Double = 1) {
        let path = CGMutablePath()
        let steps = max(64, Int(rect.width / 3))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let raw = noise.ridged(t * frequency, 0.5, octaves: octaves)
            let shaped = pow(raw, sharpness)
            let x = rect.minX + rect.width * CGFloat(t)
            let y = baseline + amplitude * CGFloat(shaped)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        context.saveGState()
        context.setFillColor(color)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    /// A perturbed lattice of quads — the base for glass, mosaic and low-poly art.
    static func jitteredLattice(rect: CGRect, columns: Int, rows: Int, jitter: CGFloat,
                                rng: inout SplitMix64) -> [[CGPoint]] {
        let stepX = rect.width / CGFloat(columns), stepY = rect.height / CGFloat(rows)
        var nodes: [[CGPoint]] = []
        for row in 0...rows {
            var line: [CGPoint] = []
            for column in 0...columns {
                var point = CGPoint(x: rect.minX + CGFloat(column) * stepX,
                                    y: rect.minY + CGFloat(row) * stepY)
                if column > 0, column < columns { point.x += rng.cg(-jitter...jitter) * stepX }
                if row > 0, row < rows { point.y += rng.cg(-jitter...jitter) * stepY }
                line.append(point)
            }
            nodes.append(line)
        }
        var cells: [[CGPoint]] = []
        cells.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                cells.append([nodes[row][column], nodes[row][column + 1],
                              nodes[row + 1][column + 1], nodes[row + 1][column]])
            }
        }
        return cells
    }

    static func fill(polygon: [CGPoint], in context: CGContext, color: CGColor,
                     stroke: CGColor? = nil, lineWidth: CGFloat = 0) {
        guard polygon.count > 2 else { return }
        context.saveGState()
        context.move(to: polygon[0])
        for point in polygon.dropFirst() { context.addLine(to: point) }
        context.closePath()
        context.setFillColor(color)
        if let stroke, lineWidth > 0 {
            context.setStrokeColor(stroke)
            context.setLineWidth(lineWidth)
            context.setLineJoin(.round)
            context.drawPath(using: .fillStroke)
        } else {
            context.fillPath()
        }
        context.restoreGState()
    }

    static func centroid(of polygon: [CGPoint]) -> CGPoint {
        guard !polygon.isEmpty else { return .zero }
        let sum = polygon.reduce(CGPoint.zero) { $0 + $1 }
        return CGPoint(x: sum.x / CGFloat(polygon.count), y: sum.y / CGFloat(polygon.count))
    }

    /// Streamlines traced through a noise field — silk, wind, currents, hair.
    static func flowStrokes(in context: CGContext, rect: CGRect, noise: PerlinNoise,
                            rng: inout SplitMix64, palette: Palette, count: Int,
                            steps: Int = 26, frequency: Double = 2.2,
                            blend: CGBlendMode = .plusLighter, widthScale: CGFloat = 1) {
        context.saveGState()
        context.setBlendMode(blend)
        context.setLineCap(.round)
        for _ in 0..<count {
            var point = rng.point(in: rect.insetBy(dx: -rect.width * 0.1, dy: -rect.height * 0.1))
            let tone = rng.double(in: 0...1)
            context.setStrokeColor(palette.cgColor(at: tone, alpha: rng.cg(0.05...0.3)))
            context.setLineWidth(rng.cg(rect.width * 0.0006...rect.width * 0.004) * widthScale)
            context.move(to: point)
            let stepLength = rect.width / CGFloat(steps) * 0.55
            for _ in 0..<steps {
                let angle = noise.fbm(Double(point.x / rect.width) * frequency,
                                      Double(point.y / rect.height) * frequency,
                                      octaves: 3) * .pi * 2.4
                point = CGPoint(x: point.x + cos(angle) * stepLength,
                                y: point.y + sin(angle) * stepLength)
                context.addLine(to: point)
            }
            context.strokePath()
        }
        context.restoreGState()
    }
}
