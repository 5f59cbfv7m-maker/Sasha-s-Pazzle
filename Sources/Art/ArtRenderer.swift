import CoreGraphics
import Foundation

/// Draws one library picture.
///
/// Every family is a short recipe over ``ArtToolkit``. Two rules hold for all of
/// them, because they are what make the pictures *usable as puzzles*:
///
/// 1. Composition happens at full resolution, but the smooth noise layers are
///    computed at roughly ⅓ scale and upsampled — invisible, and an order of
///    magnitude faster.
/// 2. Every image ends with ``ArtToolkit/detailPass(in:rect:rng:palette:intensity:)``
///    so neighbouring pieces are always distinguishable, even in a calm sky.
///
/// Drawing uses CoreGraphics' native orientation: `+y` is **up**, palette
/// position `0` is the **top** of the canvas.
nonisolated enum ArtRenderer {

    static func render(family: ArtFamily, variant: Int, size: CGSize) -> CGImage? {
        guard let context = ArtToolkit.makeContext(size: size) else { return nil }
        let rect = CGRect(origin: .zero, size: size)
        let palette = family.palette(variant: variant)
        let seed = family.seed(variant: variant)
        var rng = SplitMix64(seed: seed)
        let noise = PerlinNoise(seed: seed &* 31)

        context.setFillColor(palette.cgColor(at: 0.95))
        context.fill(rect)

        switch family {
        case .nebula: nebula(context, rect, palette, noise, &rng)
        case .galaxy: galaxy(context, rect, palette, noise, &rng)
        case .aurora: aurora(context, rect, palette, noise, &rng)
        case .planetRise: planetRise(context, rect, palette, noise, &rng)
        case .alpineRidge: alpineRidge(context, rect, palette, noise, &rng)
        case .canyon: canyon(context, rect, palette, noise, &rng)
        case .dunes: dunes(context, rect, palette, noise, &rng)
        case .iceField: iceField(context, rect, palette, noise, &rng)
        case .forest: woods(context, rect, palette, noise, &rng, autumn: false)
        case .autumnWoods: woods(context, rect, palette, noise, &rng, autumn: true)
        case .meadow: meadow(context, rect, palette, noise, &rng)
        case .tulipFields: tulipFields(context, rect, palette, noise, &rng)
        case .ocean: ocean(context, rect, palette, noise, &rng)
        case .sunsetBeach: sunsetBeach(context, rect, palette, noise, &rng)
        case .coralReef: coralReef(context, rect, palette, noise, &rng)
        case .koiPond: koiPond(context, rect, palette, noise, &rng)
        case .cityNight: city(context, rect, palette, noise, &rng, night: true)
        case .cityDusk: city(context, rect, palette, noise, &rng, night: false)
        case .harbourLights: harbour(context, rect, palette, noise, &rng)
        case .butterflies: butterflies(context, rect, palette, noise, &rng)
        case .flamingos: flamingos(context, rect, palette, noise, &rng)
        case .jellyfish: jellyfish(context, rect, palette, noise, &rng)
        case .stainedGlass: stainedGlass(context, rect, palette, noise, &rng)
        case .mosaic: mosaic(context, rect, palette, noise, &rng)
        case .lowPoly: lowPoly(context, rect, palette, noise, &rng)
        case .juliaSet: julia(context, rect, palette, &rng)
        case .marble: marble(context, rect, palette, noise, &rng)
        case .silkFlow: silk(context, rect, palette, noise, &rng)
        case .crystalCave: crystalCave(context, rect, palette, noise, &rng)
        }

        ArtToolkit.detailPass(in: context, rect: rect, rng: &rng, palette: palette,
                              intensity: family.category == .abstract ? 0.8 : 1.0)
        ArtToolkit.vignette(in: context, rect: rect, strength: 0.28)
        return context.makeImage()
    }

    // MARK: - Helpers

    private static func fieldSize(_ rect: CGRect, divisor: CGFloat = 3.2) -> (Int, Int) {
        (max(64, Int(rect.width / divisor)), max(64, Int(rect.height / divisor)))
    }

    private static func starField(_ context: CGContext, _ rect: CGRect,
                                  _ rng: inout SplitMix64, density: CGFloat = 1) {
        let count = Int(rect.width * rect.height / 5200 * density)
        let white = Palette(hex: [0xFFFFFF, 0xCFE2FF, 0xFFE8C0])
        ArtToolkit.speckle(in: context, rect: rect, rng: &rng, count: count,
                           maxRadius: rect.width * 0.0022, palette: white,
                           blend: .plusLighter, alphaRange: 0.15...1.0)
        // A handful of bright anchor stars with a cross flare.
        context.saveGState()
        context.setBlendMode(.plusLighter)
        for _ in 0..<max(6, count / 220) {
            let point = rng.point(in: rect)
            let radius = rng.cg(rect.width * 0.002...rect.width * 0.005)
            ArtToolkit.radialGlow(in: context, center: point, radius: radius * 7,
                                  color: CGColor(red: 1, green: 0.97, blue: 0.9, alpha: 0.7))
            context.setFillColor(CGColor(gray: 1, alpha: 0.95))
            context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
                                           width: radius * 2, height: radius * 2))
        }
        context.restoreGState()
    }

    // MARK: - Space

    private static func nebula(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                               _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        context.setFillColor(palette.cgColor(at: 0.02))
        context.fill(rect)
        starField(context, rect, &rng, density: 1.4)

        let (w, h) = fieldSize(rect, divisor: 3.0)
        for layer in 0..<3 {
            let scale = 1.6 + Double(layer) * 1.7
            let offset = Double(layer) * 11.3
            let field = ScalarField.generate(width: w, height: h) { x, y in
                let n = noise.warped(x * scale + offset, y * scale + offset,
                                     strength: 1.5, octaves: 6)
                return clamp(n * 0.55 + 0.5, 0, 1)
            }
            ArtToolkit.drawField(field, palette: palette, in: context, rect: rect,
                                 blend: .screen, alpha: 0.55 - CGFloat(layer) * 0.12) { value in
                let v = clamp((value - 0.42) / 0.58, 0, 1)
                return v * v
            }
        }
        for _ in 0..<rng.int(in: 2...4) {
            ArtToolkit.radialGlow(in: context, center: rng.point(in: rect),
                                  radius: rect.width * rng.cg(0.12...0.32),
                                  color: palette.cgColor(at: rng.double(in: 0.4...0.8), alpha: 0.35))
        }
        starField(context, rect, &rng, density: 0.5)
    }

    private static func galaxy(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                               _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        context.setFillColor(palette.cgColor(at: 0.01))
        context.fill(rect)
        starField(context, rect, &rng, density: 1.1)

        let arms = Double(rng.int(in: 2...4))
        let twist = rng.double(in: 4.5...8.0)
        let tilt = rng.double(in: 0.45...0.9)
        let (w, h) = fieldSize(rect, divisor: 2.6)
        let field = ScalarField.generate(width: w, height: h) { x, y in
            let dx = (x - 0.5) * 2
            let dy = (y - 0.5) * 2 / tilt
            let r = (dx * dx + dy * dy).squareRoot()
            guard r < 1.35 else { return 0 }
            let angle = atan2(dy, dx)
            let spiral = sin(angle * arms - log(max(r, 0.03)) * twist)
            let bulge = exp(-r * r * 5.5)
            let detail = noise.fbm(dx * 4 + 3, dy * 4, octaves: 5) * 0.5 + 0.5
            let arm = pow(max(0, spiral) , 2.2) * exp(-r * 1.6)
            return clamp((arm * 0.85 + bulge * 1.1) * (0.55 + detail * 0.8), 0, 1)
        }
        ArtToolkit.drawField(field, palette: palette, in: context, rect: rect,
                             blend: .screen, alpha: 0.95) { value in
            clamp(value * 1.6, 0, 1)
        }
        ArtToolkit.radialGlow(in: context, center: rect.center, radius: rect.height * 0.22,
                              color: palette.cgColor(at: 0.82, alpha: 0.55))
        starField(context, rect, &rng, density: 0.35)
    }

    private static func aurora(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                               _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect,
                                  palette: Palette([.init(position: 0, color: palette.color(at: 0.02)),
                                                    .init(position: 1, color: palette.color(at: 0.22))]))
        starField(context, rect, &rng, density: 0.9)

        context.saveGState()
        context.setBlendMode(.plusLighter)
        for curtain in 0..<rng.int(in: 3...6) {
            let baseY = rect.minY + rect.height * rng.cg(0.42...0.88)
            let height = rect.height * rng.cg(0.22...0.5)
            let tone = rng.double(in: 0.35...0.72)
            let phase = Double(curtain) * 7.7
            let steps = Int(rect.width / 3)
            for step in 0..<steps {
                let t = Double(step) / Double(steps)
                let x = rect.minX + rect.width * CGFloat(t)
                let sway = CGFloat(noise.fbm(t * 3.2 + phase, 0.3, octaves: 3)) * rect.height * 0.12
                let intensity = CGFloat(noise.fbm(t * 6 + phase, 1.7, octaves: 3) * 0.5 + 0.5)
                let top = baseY + sway + height * intensity
                let gradientColors = [palette.cgColor(at: tone, alpha: 0),
                                      palette.cgColor(at: tone, alpha: 0.5 * intensity),
                                      palette.cgColor(at: tone + 0.08, alpha: 0)]
                guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                      let gradient = CGGradient(colorsSpace: space, colors: gradientColors as CFArray,
                                                locations: [0, 0.35, 1]) else { continue }
                context.saveGState()
                context.clip(to: CGRect(x: x, y: baseY + sway, width: rect.width / CGFloat(steps) + 1,
                                        height: top - baseY - sway))
                context.drawLinearGradient(gradient, start: CGPoint(x: x, y: baseY + sway),
                                           end: CGPoint(x: x, y: top), options: [])
                context.restoreGState()
            }
        }
        context.restoreGState()

        ArtToolkit.ridgeSilhouette(in: context, rect: rect, baseline: rect.minY + rect.height * 0.06,
                                   amplitude: rect.height * 0.2, noise: noise,
                                   frequency: 5.5, octaves: 5,
                                   color: palette.cgColor(at: 0.99, alpha: 0.96))
    }

    private static func planetRise(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                   _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        context.setFillColor(palette.cgColor(at: 0.0))
        context.fill(rect)
        starField(context, rect, &rng, density: 1.3)

        let center = CGPoint(x: rect.midX + rng.cg(-0.12...0.12) * rect.width,
                             y: rect.minY + rect.height * rng.cg(0.28...0.5))
        let radius = min(rect.width, rect.height) * rng.cg(0.28...0.42)

        ArtToolkit.radialGlow(in: context, center: center, radius: radius * 1.9,
                              color: palette.cgColor(at: 0.55, alpha: 0.35))

        context.saveGState()
        context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2))
        context.clip()
        let (w, h) = fieldSize(rect, divisor: 3.4)
        let bands = rng.double(in: 5...14)
        let field = ScalarField.generate(width: w, height: h) { x, y in
            let swirl = noise.warped(x * 3.4, y * bands, strength: 0.8, octaves: 5)
            return clamp(sin(y * bands * 2.4 + swirl * 3) * 0.28 + swirl * 0.4 + 0.5, 0, 1)
        }
        ArtToolkit.drawField(field, palette: palette, in: context, rect: rect)
        // Terminator: the unlit limb.
        if let space = CGColorSpace(name: CGColorSpace.sRGB),
           let shade = CGGradient(colorsSpace: space,
                                  colors: [CGColor(gray: 0, alpha: 0),
                                           CGColor(gray: 0, alpha: 0.92)] as CFArray,
                                  locations: [0.25, 1]) {
            context.drawRadialGradient(shade,
                                       startCenter: CGPoint(x: center.x - radius * 0.45,
                                                            y: center.y + radius * 0.4),
                                       startRadius: radius * 0.2,
                                       endCenter: center, endRadius: radius * 1.5, options: [])
        }
        context.restoreGState()

        if rng.chance(0.55) {   // ring system
            context.saveGState()
            context.setBlendMode(.plusLighter)
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: rng.cg(-0.5...0.5))
            context.scaleBy(x: 1, y: rng.cg(0.16...0.3))
            for index in 0..<26 {
                let r = radius * (1.35 + CGFloat(index) * 0.035)
                context.setStrokeColor(palette.cgColor(at: rng.double(in: 0.3...0.9),
                                                       alpha: rng.cg(0.05...0.3)))
                context.setLineWidth(radius * rng.cg(0.006...0.02))
                context.strokeEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
            }
            context.restoreGState()
        }
    }

    // MARK: - Mountains & deserts

    private static func alpineRidge(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                    _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let sun = CGPoint(x: rect.minX + rect.width * rng.cg(0.2...0.8),
                          y: rect.minY + rect.height * rng.cg(0.68...0.9))
        ArtToolkit.radialGlow(in: context, center: sun, radius: rect.width * 0.35,
                              color: palette.cgColor(at: 0.55, alpha: 0.4))

        let (w, h) = fieldSize(rect)
        let clouds = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.fbm(x * 3.1, y * 1.6 + 4, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        ArtToolkit.drawField(clouds, palette: palette, in: context, rect: rect,
                             blend: .softLight, alpha: 0.5)

        let layers = rng.int(in: 4...6)
        for layer in 0..<layers {
            let depth = CGFloat(layer) / CGFloat(layers - 1)
            let ridgeNoise = PerlinNoise(seed: rng.next())
            ArtToolkit.ridgeSilhouette(
                in: context, rect: rect,
                baseline: rect.minY + rect.height * (0.12 + 0.36 * (1 - depth)),
                amplitude: rect.height * (0.16 + 0.3 * (1 - depth)),
                noise: ridgeNoise, frequency: 2.6 + Double(layer) * 1.9,
                octaves: 5 + layer,
                color: palette.cgColor(at: 0.32 + Double(depth) * 0.62, alpha: 1),
                sharpness: 1.25)
        }
        // Snow catches the light on the near ridges.
        context.saveGState()
        context.setBlendMode(.plusLighter)
        ArtToolkit.speckle(in: context, rect: rect, rng: &rng,
                           count: Int(rect.width * rect.height / 9000),
                           maxRadius: rect.width * 0.0026,
                           palette: Palette(hex: [0xFFFFFF, 0xDCEBFF]),
                           blend: .plusLighter, alphaRange: 0.05...0.4)
        context.restoreGState()
    }

    private static func canyon(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                               _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)

        let (cw, ch) = fieldSize(rect)
        let haze = ScalarField.generate(width: cw, height: ch) { x, y in
            clamp(noise.fbm(x * 3.4, y * 4.2, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.55,
                                width: rect.width, height: rect.height * 0.45))
        ArtToolkit.drawField(haze, palette: palette, in: context, rect: rect,
                             blend: .softLight, alpha: 0.6)
        context.restoreGState()

        // Sedimentary strata, rendered once and reused as the fill of every mesa.
        let (w, h) = fieldSize(rect, divisor: 2.4)
        let strata = ScalarField.generate(width: w, height: h) { x, y in
            let warp = noise.fbm(x * 1.8, y * 4.0, octaves: 5)
            let band = sin(y * 30 + warp * 6.0) * 0.5 + 0.5
            let grit = noise.fbm(x * 20, y * 30, octaves: 3) * 0.5 + 0.5
            return clamp(band * 0.6 + grit * 0.4, 0, 1)
        }

        // Mesas: quantised ridge tops give the flat-topped plateau silhouette.
        let layers = rng.int(in: 3...5)
        for layer in 0..<layers {
            let depth = Double(layer) / Double(max(1, layers - 1))
            let localNoise = PerlinNoise(seed: rng.next())
            let steps = max(48, Int(rect.width / 6))
            let baseline = rect.minY + rect.height * CGFloat(0.52 - depth * 0.34)
            let amplitude = rect.height * CGFloat(0.24 - depth * 0.1)
            let terraces = Double(rng.int(in: 3...6))

            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let raw = localNoise.fbm(t * (2.4 + depth * 3.0), 0.5, octaves: 4) * 0.5 + 0.5
                let stepped = (raw * terraces).rounded(.down) / terraces + raw * 0.14
                path.addLine(to: CGPoint(x: rect.minX + rect.width * CGFloat(t),
                                         y: baseline + amplitude * CGFloat(stepped)))
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()

            context.saveGState()
            context.addPath(path)
            context.clip()
            ArtToolkit.drawField(strata, palette: palette, in: context, rect: rect, alpha: 1)
            // Nearer mesas fall into shadow, which is what reads as depth.
            context.setFillColor(CGColor(gray: 0, alpha: CGFloat(depth) * 0.45))
            context.fill(rect)
            context.restoreGState()

            context.addPath(path)
            context.setStrokeColor(palette.cgColor(at: 0.98, alpha: 0.5))
            context.setLineWidth(rect.width * 0.0016)
            context.strokePath()
        }
    }

    private static func dunes(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                              _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let sun = CGPoint(x: rect.minX + rect.width * rng.cg(0.15...0.85),
                          y: rect.minY + rect.height * rng.cg(0.72...0.92))
        ArtToolkit.radialGlow(in: context, center: sun, radius: rect.width * 0.22,
                              color: palette.cgColor(at: 0.16, alpha: 0.45))

        let layers = rng.int(in: 5...8)
        for layer in 0..<layers {
            let depth = Double(layer) / Double(layers - 1)
            let localNoise = PerlinNoise(seed: rng.next())
            let path = CGMutablePath()
            let steps = Int(rect.width / 4)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            let baseline = rect.minY + rect.height * CGFloat(0.62 - depth * 0.52)
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let wave = sin(t * (2.4 + depth * 5) * .pi + depth * 4) * 0.5
                let n = localNoise.fbm(t * (2.6 + depth * 3), 0.4, octaves: 4)
                let y = baseline + rect.height * CGFloat((wave * 0.06 + n * 0.09) * (1.2 - depth * 0.5))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * CGFloat(t), y: y))
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
            // Alternating tones keep adjacent dunes readable as separate ridges.
            let banding = (layer % 2 == 0 ? 0.0 : 0.13)
            context.setFillColor(palette.cgColor(at: clamp(0.24 + depth * 0.68 + banding, 0, 1)))
            context.addPath(path)
            context.fillPath()
        }
        // Wind ripples.
        context.saveGState()
        context.setBlendMode(.softLight)
        for _ in 0..<Int(rect.width * 0.9) {
            let start = rng.point(in: CGRect(x: rect.minX, y: rect.minY,
                                             width: rect.width, height: rect.height * 0.62))
            let length = rng.cg(rect.width * 0.01...rect.width * 0.07)
            context.setStrokeColor(palette.cgColor(at: rng.double(in: 0.2...0.9), alpha: rng.cg(0.05...0.22)))
            context.setLineWidth(rect.width * 0.0012)
            context.move(to: start)
            context.addQuadCurve(to: CGPoint(x: start.x + length, y: start.y),
                                 control: CGPoint(x: start.x + length / 2,
                                                  y: start.y + rng.cg(-0.004...0.004) * rect.height))
            context.strokePath()
        }
        context.restoreGState()
    }

    private static func iceField(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                 _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let (w, h) = fieldSize(rect)
        let sky = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.warped(x * 2.6, y * 2.1, strength: 1.0, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        ArtToolkit.drawField(sky, palette: palette, in: context, rect: rect,
                             blend: .softLight, alpha: 0.55)
        ArtToolkit.ridgeSilhouette(in: context, rect: rect,
                                   baseline: rect.minY + rect.height * 0.42,
                                   amplitude: rect.height * 0.16, noise: noise,
                                   frequency: 4.2, octaves: 5,
                                   color: palette.cgColor(at: 0.68, alpha: 1), sharpness: 1.8)

        let water = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.45)
        context.setFillColor(palette.cgColor(at: 0.92))
        context.fill(water)

        // Floating ice floes as an irregular tessellation.
        var floeRNG = SplitMix64(seed: rng.next())
        let cells = ArtToolkit.jitteredLattice(rect: water.insetBy(dx: -water.width * 0.05, dy: -water.height * 0.2),
                                               columns: rng.int(in: 9...16), rows: rng.int(in: 4...7),
                                               jitter: 0.36, rng: &floeRNG)
        for cell in cells where floeRNG.chance(0.78) {
            let shrunk = cell.map { point -> CGPoint in
                let c = ArtToolkit.centroid(of: cell)
                let k = floeRNG.cg(0.72...0.94)
                return CGPoint(x: c.x + (point.x - c.x) * k, y: c.y + (point.y - c.y) * k)
            }
            let tone = floeRNG.double(in: 0.42...0.78)
            ArtToolkit.fill(polygon: shrunk, in: context, color: palette.cgColor(at: tone, alpha: 0.94),
                            stroke: palette.cgColor(at: 0.2, alpha: 0.5), lineWidth: rect.width * 0.0012)
        }
    }

    // MARK: - Forests & fields

    private static func woods(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                              _ noise: PerlinNoise, _ rng: inout SplitMix64, autumn: Bool) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let (w, h) = fieldSize(rect, divisor: 2.8)
        let haze = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.fbm(x * 3.4, y * 2.2, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        ArtToolkit.drawField(haze, palette: palette, in: context, rect: rect,
                             blend: .softLight, alpha: 0.6)

        // Trunks recede in three depth bands: thinner, paler, more numerous behind.
        for band in 0..<3 {
            let depth = Double(band) / 2
            let count = Int(rect.width / CGFloat(26 + band * 18))
            for _ in 0..<count {
                let x = rng.cg(rect.minX...rect.maxX)
                let width = rect.width * CGFloat(0.004 + depth * 0.012) * rng.cg(0.6...1.6)
                let top = rect.minY + rect.height * rng.cg(0.55...1.0)
                // Aerial perspective: distant trunks pale out, near ones go dark.
                let tone = 0.62 - depth * 0.46
                context.setFillColor(palette.cgColor(at: tone, alpha: CGFloat(0.5 + depth * 0.5)))
                let lean = rng.cg(-0.02...0.02) * rect.width
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x + lean, y: top))
                path.addLine(to: CGPoint(x: x + lean + width, y: top))
                path.addLine(to: CGPoint(x: x + width, y: rect.minY))
                path.closeSubpath()
                context.addPath(path)
                context.fillPath()
            }
        }

        // Canopy: dense speckle of leaves, warm in autumn, cool in summer.
        let canopy = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.42,
                            width: rect.width, height: rect.height * 0.58)
        ArtToolkit.speckle(in: context, rect: canopy, rng: &rng,
                           count: Int(rect.width * rect.height / 900),
                           maxRadius: rect.width * 0.008,
                           palette: palette, blend: autumn ? .normal : .normal,
                           alphaRange: 0.25...0.85)
        // Forest floor.
        let floor = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.28)
        ArtToolkit.speckle(in: context, rect: floor, rng: &rng,
                           count: Int(rect.width * rect.height / 2400),
                           maxRadius: rect.width * 0.006, palette: palette,
                           blend: .normal, alphaRange: 0.3...0.9)
        // Light shafts.
        context.saveGState()
        context.setBlendMode(.plusLighter)
        for _ in 0..<rng.int(in: 3...7) {
            let x = rng.cg(rect.minX...rect.maxX)
            let width = rect.width * rng.cg(0.02...0.09)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + width, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + width * 2.6, y: rect.minY))
            path.addLine(to: CGPoint(x: x - width * 0.6, y: rect.minY))
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(palette.cgColor(at: autumn ? 0.72 : 0.62, alpha: 0.09))
            context.fillPath()
        }
        context.restoreGState()
    }

    private static func meadow(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                               _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let horizon = rect.minY + rect.height * rng.cg(0.5...0.66)

        let (w, h) = fieldSize(rect, divisor: 3.0)
        let clouds = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.fbm(x * 3.6, y * 2.4, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: horizon, width: rect.width, height: rect.maxY - horizon))
        ArtToolkit.drawField(clouds, palette: Palette(hex: [0xFFFFFF, 0xE8F2FF]), in: context,
                             rect: rect, blend: .softLight, alpha: 0.85) { max(0, ($0 - 0.52) * 2.4) }
        context.restoreGState()

        // Distant treeline anchors the horizon.
        ArtToolkit.ridgeSilhouette(in: context, rect: rect, baseline: horizon - rect.height * 0.03,
                                   amplitude: rect.height * 0.07, noise: PerlinNoise(seed: rng.next()),
                                   frequency: 14, octaves: 5,
                                   color: palette.cgColor(at: 0.92, alpha: 0.9), sharpness: 1.4)

        context.setFillColor(palette.cgColor(at: 0.5))
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: horizon - rect.minY))

        // Three depth bands of grass. Near blades are long, dark and sparse;
        // distant ones short, pale and dense — that gradient is the whole effect.
        for band in 0..<3 {
            let depth = CGFloat(band) / 2
            let top = horizon - (horizon - rect.minY) * depth * 0.62
            let bottom = horizon - (horizon - rect.minY) * min(1, (depth + 0.5) * 0.62)
            let count = Int(rect.width * (3.4 - depth * 1.8))
            context.saveGState()
            for _ in 0..<count {
                let x = rng.cg(rect.minX...rect.maxX)
                let y = rng.cg(min(top, bottom)...max(top, bottom))
                let length = rect.height * (0.03 + 0.075 * depth)
                context.setStrokeColor(palette.cgColor(at: rng.double(in: 0.28...0.92),
                                                       alpha: rng.cg(0.35...0.9)))
                context.setLineWidth(rect.width * (0.0007 + 0.0016 * depth))
                context.move(to: CGPoint(x: x, y: y))
                context.addQuadCurve(to: CGPoint(x: x + rng.cg(-0.018...0.018) * rect.width, y: y + length),
                                     control: CGPoint(x: x + rng.cg(-0.01...0.01) * rect.width,
                                                      y: y + length * 0.62))
                context.strokePath()
            }
            context.restoreGState()
        }

        // Wildflowers, larger and warmer as they come forward.
        for _ in 0..<Int(rect.width * 1.1) {
            let y = rng.cg(rect.minY...(horizon - rect.height * 0.01))
            let depth = 1 - (y - rect.minY) / max(1, horizon - rect.minY)
            let radius = rect.width * (0.0018 + 0.006 * depth) * rng.cg(0.6...1.4)
            let point = CGPoint(x: rng.cg(rect.minX...rect.maxX), y: y)
            let tone = rng.chance(0.5) ? rng.double(in: 0.6...0.78) : rng.double(in: 0.0...0.2)
            context.setFillColor(palette.cgColor(at: tone, alpha: rng.cg(0.7...1.0)))
            context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
                                           width: radius * 2, height: radius * 2))
        }
    }

    private static func tulipFields(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                    _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let horizon = rect.minY + rect.height * rng.cg(0.58...0.72)

        let (w, h) = fieldSize(rect)
        let clouds = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.fbm(x * 3.2, y * 2.0, octaves: 4) * 0.5 + 0.5, 0, 1)
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: horizon, width: rect.width, height: rect.maxY - horizon))
        ArtToolkit.drawField(clouds, palette: Palette(hex: [0xFFFFFF, 0xDCE8F6]), in: context,
                             rect: rect, blend: .softLight, alpha: 0.8) { max(0, ($0 - 0.5) * 2.2) }
        context.restoreGState()

        ArtToolkit.ridgeSilhouette(in: context, rect: rect, baseline: horizon - rect.height * 0.02,
                                   amplitude: rect.height * 0.05, noise: PerlinNoise(seed: rng.next()),
                                   frequency: 18, octaves: 4,
                                   color: palette.cgColor(at: 0.95, alpha: 0.85), sharpness: 1.3)

        // Colour rows run the full width; their height grows toward the viewer,
        // which is all the perspective a flat field needs.
        let rows = rng.int(in: 10...18)
        var previousY = horizon
        for row in 0..<rows {
            let t = Double(row + 1) / Double(rows)
            let y = horizon - CGFloat(pow(t, 2.0)) * (horizon - rect.minY)
            let band = CGRect(x: rect.minX, y: y, width: rect.width, height: previousY - y)
            let tone = rng.double(in: 0.1...0.85)
            context.setFillColor(palette.cgColor(at: tone, alpha: 1))
            context.fill(band.insetBy(dx: 0, dy: -0.5))

            // Individual blooms so a stripe never reads as flat colour.
            let bloomRadius = max(0.8, rect.width * 0.0016 * CGFloat(0.6 + t * 3.4))
            ArtToolkit.speckle(in: context, rect: band, rng: &rng,
                               count: Int(band.height * rect.width / 220) + 40,
                               maxRadius: bloomRadius, palette: palette,
                               blend: .normal, alphaRange: 0.35...0.95)
            // A darker furrow between rows.
            context.setFillColor(CGColor(gray: 0, alpha: 0.18))
            context.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: max(1, band.height * 0.08)))
            previousY = y
        }
    }

    // MARK: - Water

    private static func ocean(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                              _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let horizon = rect.minY + rect.height * rng.cg(0.52...0.7)
        let (w, h) = fieldSize(rect, divisor: 2.4)
        // Perspective compression: swell frequency rises toward the horizon.
        let water = ScalarField.generate(width: w, height: h) { x, y in
            let depth = clamp((y - 0.32) / 0.68, 0.001, 1)
            let compression = 1 / (depth * depth + 0.02)
            let swell = sin((y * 40 * compression * 0.05) + noise.fbm(x * 4, y * 9, octaves: 4) * 4)
            let ripple = noise.fbm(x * 16 * compression * 0.14, y * 44, octaves: 4)
            return clamp(0.55 + swell * 0.16 + ripple * 0.34, 0, 1)
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: horizon - rect.minY))
        ArtToolkit.drawField(water, palette: palette, in: context, rect: rect, alpha: 1)
        context.restoreGState()

        // Breaking crests.
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: horizon - rect.minY))
        context.setBlendMode(.plusLighter)
        for _ in 0..<Int(rect.width * 1.1) {
            let y = rng.cg(rect.minY...horizon)
            let depth = (y - rect.minY) / max(1, horizon - rect.minY)
            let x = rng.cg(rect.minX...rect.maxX)
            let length = rect.width * rng.cg(0.006...0.06) * (1.3 - depth)
            context.setStrokeColor(palette.cgColor(at: 0.02, alpha: rng.cg(0.1...0.55)))
            context.setLineWidth(rect.height * 0.0016 * (1.4 - depth))
            context.move(to: CGPoint(x: x, y: y))
            context.addQuadCurve(to: CGPoint(x: x + length, y: y + rng.cg(-0.003...0.003) * rect.height),
                                 control: CGPoint(x: x + length / 2, y: y + rng.cg(-0.006...0.006) * rect.height))
            context.strokePath()
        }
        context.restoreGState()

        let (cw, ch) = fieldSize(rect)
        let clouds = ScalarField.generate(width: cw, height: ch) { x, y in
            clamp(noise.fbm(x * 3.0 + 9, y * 2.0, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: horizon, width: rect.width, height: rect.maxY - horizon))
        ArtToolkit.drawField(clouds, palette: palette, in: context, rect: rect,
                             blend: .softLight, alpha: 0.6)
        context.restoreGState()
    }

    private static func sunsetBeach(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                    _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let horizon = rect.minY + rect.height * rng.cg(0.42...0.55)
        let sunX = rect.minX + rect.width * rng.cg(0.25...0.75)
        let sunRadius = rect.width * rng.cg(0.05...0.09)
        let sun = CGPoint(x: sunX, y: horizon + sunRadius * rng.cg(0.1...1.2))

        ArtToolkit.radialGlow(in: context, center: sun, radius: sunRadius * 9,
                              color: palette.cgColor(at: 0.42, alpha: 0.5))
        context.setFillColor(palette.cgColor(at: 0.3, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: sun.x - sunRadius, y: sun.y - sunRadius,
                                       width: sunRadius * 2, height: sunRadius * 2))

        // Streaked clouds.
        let (w, h) = fieldSize(rect, divisor: 2.8)
        let clouds = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.fbm(x * 2.2, y * 9.5, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: horizon, width: rect.width, height: rect.maxY - horizon))
        ArtToolkit.drawField(clouds, palette: palette, in: context, rect: rect,
                             blend: .screen, alpha: 0.65) { max(0, ($0 - 0.5) * 2) }
        context.restoreGState()

        // Sea with a glitter path under the sun.
        context.setFillColor(palette.cgColor(at: 0.78))
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: horizon - rect.minY))
        context.saveGState()
        context.setBlendMode(.plusLighter)
        for _ in 0..<Int(rect.width * 1.4) {
            let y = rng.cg(rect.minY + rect.height * 0.05...horizon)
            let spread = rect.width * 0.06 * (1 + (horizon - y) / rect.height * 8)
            let x = sunX + rng.cg(-spread...spread)
            let length = rect.width * rng.cg(0.004...0.03)
            context.setStrokeColor(palette.cgColor(at: rng.double(in: 0.2...0.45), alpha: rng.cg(0.1...0.7)))
            context.setLineWidth(rect.height * rng.cg(0.001...0.004))
            context.move(to: CGPoint(x: x - length / 2, y: y))
            context.addLine(to: CGPoint(x: x + length / 2, y: y))
            context.strokePath()
        }
        context.restoreGState()

        // Wet sand foreground.
        let sand = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.16)
        context.setFillColor(palette.cgColor(at: 0.9, alpha: 0.9))
        context.fill(sand)
        ArtToolkit.speckle(in: context, rect: sand, rng: &rng,
                           count: Int(rect.width * 1.6), maxRadius: rect.width * 0.002,
                           palette: palette, blend: .normal, alphaRange: 0.15...0.6)
    }

    private static func coralReef(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                  _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        // Caustics.
        let (w, h) = fieldSize(rect, divisor: 2.6)
        let caustics = ScalarField.generate(width: w, height: h) { x, y in
            let n = noise.warped(x * 5.5, y * 5.5, strength: 0.9, octaves: 4)
            return clamp(pow(max(0, n + 0.35), 3.2) * 2.2, 0, 1)
        }
        ArtToolkit.drawField(caustics, palette: Palette(hex: [0x000000, 0xE8FFFF]), in: context,
                             rect: rect, blend: .plusLighter, alpha: 0.4) { $0 }

        // Coral colonies: recursive branch clusters along the sea floor.
        for _ in 0..<rng.int(in: 8...15) {
            let base = CGPoint(x: rng.cg(rect.minX...rect.maxX),
                               y: rect.minY + rng.cg(0...0.12) * rect.height)
            let size = rect.height * rng.cg(0.16...0.42)
            let tone = rng.double(in: 0.3...0.95)
            branch(context, from: base, angle: .pi / 2 + rng.cg(-0.3...0.3), length: size * 0.5,
                   width: size * 0.13, depth: rng.int(in: 4...5),
                   color: palette.cgColor(at: tone, alpha: 0.96), rng: &rng)
        }
        // Fish.
        for _ in 0..<rng.int(in: 20...50) {
            let point = rng.point(in: rect)
            let size = rect.width * rng.cg(0.006...0.018)
            context.saveGState()
            context.translateBy(x: point.x, y: point.y)
            context.rotate(by: rng.cg(-0.5...0.5))
            context.setFillColor(palette.cgColor(at: rng.double(in: 0.35...1.0), alpha: 0.9))
            context.fillEllipse(in: CGRect(x: -size, y: -size * 0.4, width: size * 2, height: size * 0.8))
            context.move(to: CGPoint(x: -size, y: 0))
            context.addLine(to: CGPoint(x: -size * 1.7, y: size * 0.5))
            context.addLine(to: CGPoint(x: -size * 1.7, y: -size * 0.5))
            context.closePath()
            context.fillPath()
            context.restoreGState()
        }
        ArtToolkit.speckle(in: context, rect: rect, rng: &rng, count: Int(rect.width * 0.9),
                           maxRadius: rect.width * 0.0028, palette: Palette(hex: [0xFFFFFF, 0xBFEFFF]),
                           blend: .plusLighter, alphaRange: 0.1...0.5)
    }

    /// Recursive branch used by corals and crystals.
    private static func branch(_ context: CGContext, from point: CGPoint, angle: CGFloat,
                               length: CGFloat, width: CGFloat, depth: Int,
                               color: CGColor, rng: inout SplitMix64) {
        guard depth > 0, length > 1 else { return }
        let end = CGPoint(x: point.x + cos(angle) * length, y: point.y + sin(angle) * length)
        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(max(0.6, width))
        context.setLineCap(.round)
        context.move(to: point)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
        let children = rng.int(in: 2...3)
        for _ in 0..<children {
            branch(context, from: end, angle: angle + rng.cg(-0.7...0.7),
                   length: length * rng.cg(0.5...0.72), width: width * 0.62,
                   depth: depth - 1, color: color, rng: &rng)
        }
    }

    private static func koiPond(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        let (w, h) = fieldSize(rect, divisor: 2.6)
        let water = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.warped(x * 3.4, y * 3.4, strength: 1.3, octaves: 5) * 0.5 + 0.45, 0, 1)
        }
        ArtToolkit.drawField(water, palette: palette, in: context, rect: rect)

        // Ripples.
        context.saveGState()
        context.setBlendMode(.softLight)
        for _ in 0..<rng.int(in: 8...18) {
            let center = rng.point(in: rect)
            for ring in 0..<rng.int(in: 3...7) {
                let radius = rect.width * (0.012 + CGFloat(ring) * rng.cg(0.012...0.03))
                context.setStrokeColor(palette.cgColor(at: 0.1, alpha: 0.22 / CGFloat(ring + 1)))
                context.setLineWidth(rect.width * 0.0016)
                context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                                 width: radius * 2, height: radius * 2))
            }
        }
        context.restoreGState()

        // Lily pads.
        for _ in 0..<rng.int(in: 10...24) {
            let center = rng.point(in: rect)
            let radius = rect.width * rng.cg(0.02...0.055)
            let notch = rng.cg(0...(.pi * 2))
            context.saveGState()
            context.setFillColor(palette.cgColor(at: rng.double(in: 0.28...0.5), alpha: 0.95))
            context.addArc(center: center, radius: radius, startAngle: notch + 0.35,
                           endAngle: notch - 0.35, clockwise: false)
            context.addLine(to: center)
            context.closePath()
            context.fillPath()
            context.restoreGState()
        }

        // Koi.
        for _ in 0..<rng.int(in: 5...12) {
            let center = rng.point(in: rect)
            let size = rect.width * rng.cg(0.03...0.075)
            let angle = rng.cg(0...(.pi * 2))
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: angle)
            context.setFillColor(palette.cgColor(at: rng.chance(0.6) ? 0.72 : 0.9, alpha: 0.95))
            context.fillEllipse(in: CGRect(x: -size, y: -size * 0.3, width: size * 2, height: size * 0.6))
            context.move(to: CGPoint(x: -size * 0.95, y: 0))
            context.addLine(to: CGPoint(x: -size * 1.8, y: size * 0.42))
            context.addLine(to: CGPoint(x: -size * 1.8, y: -size * 0.42))
            context.closePath()
            context.fillPath()
            context.setFillColor(palette.cgColor(at: 0.62, alpha: 0.85))
            for _ in 0..<rng.int(in: 2...5) {
                let spot = rng.cg(-size * 0.7...size * 0.7)
                let r = size * rng.cg(0.08...0.2)
                context.fillEllipse(in: CGRect(x: spot - r, y: rng.cg(-size * 0.2...size * 0.2) - r,
                                               width: r * 2, height: r * 2))
            }
            context.restoreGState()
        }
    }

    // MARK: - City

    private static func city(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                             _ noise: PerlinNoise, _ rng: inout SplitMix64, night: Bool) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        if night { starField(context, rect, &rng, density: 0.6) }

        let (w, h) = fieldSize(rect)
        let haze = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.fbm(x * 2.6, y * 3.4, octaves: 4) * 0.5 + 0.5, 0, 1)
        }
        ArtToolkit.drawField(haze, palette: palette, in: context, rect: rect,
                             blend: .softLight, alpha: 0.45)

        let waterLine = rect.minY + rect.height * rng.cg(0.12...0.26)
        let skyline = CGRect(x: rect.minX, y: waterLine, width: rect.width, height: rect.height)

        // Three depth bands of towers, back to front.
        for band in 0..<3 {
            let depth = Double(band) / 2
            let tone = 0.24 + (1 - depth) * 0.55
            var x = rect.minX - rect.width * 0.05
            while x < rect.maxX {
                let width = rect.width * CGFloat(0.02 + depth * 0.05) * rng.cg(0.6...1.7)
                let height = rect.height * CGFloat(0.1 + depth * 0.16) * rng.cg(0.5...2.6)
                let tower = CGRect(x: x, y: waterLine, width: width, height: height)
                context.setFillColor(palette.cgColor(at: tone, alpha: 1))
                context.fill(tower)
                if rng.chance(0.25) {   // spire
                    context.fill(CGRect(x: tower.midX - width * 0.06, y: tower.maxY,
                                        width: width * 0.12, height: height * rng.cg(0.06...0.3)))
                }
                if band == 2 || rng.chance(0.6) {
                    windows(context, in: tower, palette: palette, rng: &rng,
                            night: night, density: CGFloat(0.35 + depth * 0.5))
                }
                x += width * rng.cg(1.02...1.5)
            }
            _ = skyline
        }

        // Reflection in the water.
        context.saveGState()
        let water = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: waterLine - rect.minY)
        context.clip(to: water)
        context.translateBy(x: 0, y: waterLine * 2)
        context.scaleBy(x: 1, y: -1)
        context.setAlpha(0.42)
        if let snapshot = context.makeImage() {
            context.draw(snapshot, in: rect)
        }
        context.restoreGState()
        context.saveGState()
        context.clip(to: water)
        context.setFillColor(palette.cgColor(at: 0.98, alpha: 0.45))
        context.fill(water)
        context.setBlendMode(.plusLighter)
        for _ in 0..<Int(rect.width * 1.2) {
            let y = rng.cg(water.minY...water.maxY)
            let x = rng.cg(rect.minX...rect.maxX)
            let length = rect.width * rng.cg(0.004...0.026)
            context.setStrokeColor(palette.cgColor(at: rng.double(in: 0.55...0.95), alpha: rng.cg(0.06...0.4)))
            context.setLineWidth(rect.height * 0.0022)
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + length, y: y))
            context.strokePath()
        }
        context.restoreGState()
    }

    private static func windows(_ context: CGContext, in tower: CGRect, palette: Palette,
                                rng: inout SplitMix64, night: Bool, density: CGFloat) {
        let cell = max(2.0, tower.width * 0.14)
        let columns = max(1, Int(tower.width / cell) - 1)
        let rows = max(1, Int(tower.height / (cell * 1.6)) - 1)
        guard columns * rows < 20000 else { return }
        context.saveGState()
        context.setBlendMode(night ? .plusLighter : .normal)
        for row in 0..<rows {
            for column in 0..<columns {
                guard rng.chance(Double(night ? density : density * 0.5)) else { continue }
                let frame = CGRect(x: tower.minX + cell * 0.6 + CGFloat(column) * cell,
                                   y: tower.minY + cell * 0.8 + CGFloat(row) * cell * 1.6,
                                   width: cell * 0.55, height: cell * 0.85)
                guard tower.contains(frame) else { continue }
                let tone = night ? rng.double(in: 0.55...0.85) : rng.double(in: 0.05...0.25)
                context.setFillColor(palette.cgColor(at: tone, alpha: rng.cg(0.35...1.0)))
                context.fill(frame)
            }
        }
        context.restoreGState()
    }

    private static func harbour(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        starField(context, rect, &rng, density: 0.5)
        let waterLine = rect.minY + rect.height * rng.cg(0.3...0.44)

        // Quay silhouette with cranes and masts.
        context.setFillColor(palette.cgColor(at: 0.12, alpha: 1))
        context.fill(CGRect(x: rect.minX, y: waterLine, width: rect.width, height: rect.height * 0.06))
        for _ in 0..<rng.int(in: 6...14) {
            let x = rng.cg(rect.minX...rect.maxX)
            let height = rect.height * rng.cg(0.08...0.32)
            context.setStrokeColor(palette.cgColor(at: 0.1, alpha: 1))
            context.setLineWidth(rect.width * rng.cg(0.0015...0.005))
            context.move(to: CGPoint(x: x, y: waterLine))
            context.addLine(to: CGPoint(x: x, y: waterLine + height))
            if rng.chance(0.4) {
                context.addLine(to: CGPoint(x: x + rect.width * rng.cg(0.02...0.07),
                                            y: waterLine + height * rng.cg(0.8...0.95)))
            }
            context.strokePath()
        }
        // Warm lamps and their long reflections.
        var lamps: [CGPoint] = []
        for _ in 0..<rng.int(in: 30...80) {
            let point = CGPoint(x: rng.cg(rect.minX...rect.maxX),
                                y: waterLine + rng.cg(0...0.16) * rect.height)
            lamps.append(point)
            ArtToolkit.radialGlow(in: context, center: point, radius: rect.width * rng.cg(0.01...0.035),
                                  color: palette.cgColor(at: rng.double(in: 0.6...0.85), alpha: 0.8))
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: waterLine - rect.minY))
        context.setFillColor(palette.cgColor(at: 0.95))
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: waterLine - rect.minY))
        context.setBlendMode(.plusLighter)
        for lamp in lamps {
            let tone = rng.double(in: 0.6...0.85)
            var y = waterLine
            while y > rect.minY {
                let jitter = rng.cg(-0.012...0.012) * rect.width
                let width = rect.width * rng.cg(0.004...0.016)
                context.setFillColor(palette.cgColor(at: tone, alpha: rng.cg(0.05...0.35)))
                context.fill(CGRect(x: lamp.x + jitter - width / 2, y: y,
                                    width: width, height: rect.height * 0.006))
                y -= rect.height * rng.cg(0.008...0.02)
            }
        }
        context.restoreGState()
        let (w, h) = fieldSize(rect, divisor: 2.4)
        let ripples = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.fbm(x * 8, y * 30, octaves: 4) * 0.5 + 0.5, 0, 1)
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: waterLine - rect.minY))
        ArtToolkit.drawField(ripples, palette: palette, in: context, rect: rect,
                             blend: .softLight, alpha: 0.5)
        context.restoreGState()
    }

    // MARK: - Animals

    private static func butterflies(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                    _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        let (w, h) = fieldSize(rect, divisor: 3.0)
        let backdrop = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.warped(x * 2.4, y * 2.4, strength: 1.1, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        ArtToolkit.drawField(backdrop, palette: palette, in: context, rect: rect)
        ArtToolkit.speckle(in: context, rect: rect, rng: &rng, count: Int(rect.width * 0.8),
                           maxRadius: rect.width * 0.004, palette: palette,
                           blend: .normal, alphaRange: 0.15...0.5)

        for _ in 0..<rng.int(in: 18...42) {
            let center = rng.point(in: rect)
            let size = rect.width * rng.cg(0.02...0.075)
            let angle = rng.cg(0...(.pi * 2))
            let tone = rng.double(in: 0.1...0.95)
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: angle)
            context.setFillColor(palette.cgColor(at: tone, alpha: 0.94))
            for side in [CGFloat(1), CGFloat(-1)] {
                context.saveGState()
                context.scaleBy(x: 1, y: side)
                let upper = CGMutablePath()
                upper.move(to: .zero)
                upper.addCurve(to: CGPoint(x: size * 0.9, y: size * 0.75),
                               control1: CGPoint(x: size * 0.1, y: size * 0.7),
                               control2: CGPoint(x: size * 0.6, y: size * 0.95))
                upper.addCurve(to: .zero, control1: CGPoint(x: size * 1.0, y: size * 0.15),
                               control2: CGPoint(x: size * 0.35, y: size * 0.1))
                context.addPath(upper)
                context.fillPath()
                let lower = CGMutablePath()
                lower.move(to: .zero)
                lower.addCurve(to: CGPoint(x: -size * 0.7, y: size * 0.55),
                               control1: CGPoint(x: -size * 0.1, y: size * 0.5),
                               control2: CGPoint(x: -size * 0.55, y: size * 0.7))
                lower.addCurve(to: .zero, control1: CGPoint(x: -size * 0.8, y: size * 0.1),
                               control2: CGPoint(x: -size * 0.3, y: size * 0.05))
                context.addPath(lower)
                context.fillPath()
                context.restoreGState()
            }
            // Wing markings keep large butterflies from being flat colour.
            context.setFillColor(palette.cgColor(at: 1 - tone, alpha: 0.7))
            for _ in 0..<rng.int(in: 2...5) {
                let r = size * rng.cg(0.06...0.15)
                context.fillEllipse(in: CGRect(x: rng.cg(-size * 0.5...size * 0.7) - r,
                                               y: rng.cg(-size * 0.6...size * 0.6) - r,
                                               width: r * 2, height: r * 2))
            }
            context.setFillColor(palette.cgColor(at: 0.98, alpha: 0.95))
            context.fill(CGRect(x: -size * 0.06, y: -size * 0.32, width: size * 0.12, height: size * 0.64))
            context.restoreGState()
        }
    }

    private static func flamingos(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                  _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let waterLine = rect.minY + rect.height * rng.cg(0.45...0.65)
        context.setFillColor(palette.cgColor(at: 0.82))
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: waterLine - rect.minY))

        let (w, h) = fieldSize(rect, divisor: 2.6)
        let ripples = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.fbm(x * 6, y * 26, octaves: 4) * 0.5 + 0.5, 0, 1)
        }
        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: waterLine - rect.minY))
        ArtToolkit.drawField(ripples, palette: palette, in: context, rect: rect,
                             blend: .softLight, alpha: 0.6)
        context.restoreGState()

        for _ in 0..<rng.int(in: 5...12) {
            let base = CGPoint(x: rng.cg(rect.minX...rect.maxX),
                               y: waterLine - rng.cg(0...0.1) * rect.height)
            let scale = rect.height * rng.cg(0.16...0.36)
            let tone = rng.double(in: 0.15...0.45)
            context.saveGState()
            context.setStrokeColor(palette.cgColor(at: tone, alpha: 0.95))
            context.setFillColor(palette.cgColor(at: tone, alpha: 0.95))
            context.setLineWidth(scale * 0.045)
            context.setLineCap(.round)
            // Legs
            for offset in [CGFloat(-0.05), 0.05] {
                context.move(to: CGPoint(x: base.x + scale * offset, y: base.y))
                context.addLine(to: CGPoint(x: base.x + scale * offset * 2.2, y: base.y + scale * 0.42))
                context.strokePath()
            }
            // Body
            let bodyCenter = CGPoint(x: base.x, y: base.y + scale * 0.52)
            context.fillEllipse(in: CGRect(x: bodyCenter.x - scale * 0.26, y: bodyCenter.y - scale * 0.16,
                                           width: scale * 0.52, height: scale * 0.32))
            // S-neck and head
            context.setLineWidth(scale * 0.055)
            context.move(to: CGPoint(x: bodyCenter.x + scale * 0.2, y: bodyCenter.y + scale * 0.08))
            context.addCurve(to: CGPoint(x: bodyCenter.x + scale * 0.34, y: bodyCenter.y + scale * 0.5),
                             control1: CGPoint(x: bodyCenter.x + scale * 0.5, y: bodyCenter.y + scale * 0.22),
                             control2: CGPoint(x: bodyCenter.x + scale * 0.1, y: bodyCenter.y + scale * 0.44))
            context.strokePath()
            context.fillEllipse(in: CGRect(x: bodyCenter.x + scale * 0.28, y: bodyCenter.y + scale * 0.46,
                                           width: scale * 0.13, height: scale * 0.1))
            context.setFillColor(palette.cgColor(at: 0.95, alpha: 0.95))
            context.move(to: CGPoint(x: bodyCenter.x + scale * 0.39, y: bodyCenter.y + scale * 0.52))
            context.addLine(to: CGPoint(x: bodyCenter.x + scale * 0.5, y: bodyCenter.y + scale * 0.44))
            context.addLine(to: CGPoint(x: bodyCenter.x + scale * 0.38, y: bodyCenter.y + scale * 0.46))
            context.closePath()
            context.fillPath()
            // Reflection
            context.saveGState()
            context.setAlpha(0.3)
            context.translateBy(x: 0, y: base.y * 2)
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(palette.cgColor(at: tone, alpha: 0.6))
            context.fillEllipse(in: CGRect(x: bodyCenter.x - scale * 0.26, y: bodyCenter.y - scale * 0.16,
                                           width: scale * 0.52, height: scale * 0.32))
            context.restoreGState()
            context.restoreGState()
        }
    }

    private static func jellyfish(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                  _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        ArtToolkit.linearGradient(in: context, rect: rect, palette: palette)
        let (w, h) = fieldSize(rect, divisor: 3.0)
        let depths = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.warped(x * 2.2, y * 2.2, strength: 1.4, octaves: 5) * 0.5 + 0.5, 0, 1)
        }
        ArtToolkit.drawField(depths, palette: palette, in: context, rect: rect,
                             blend: .screen, alpha: 0.4)

        for _ in 0..<rng.int(in: 5...11) {
            let center = rng.point(in: rect)
            let size = rect.height * rng.cg(0.07...0.17)
            let tone = rng.double(in: 0.3...0.9)
            ArtToolkit.radialGlow(in: context, center: center, radius: size * 1.8,
                                  color: palette.cgColor(at: tone, alpha: 0.16))
            context.saveGState()
            context.setBlendMode(.plusLighter)
            // Bell
            let bell = CGMutablePath()
            bell.move(to: CGPoint(x: center.x - size, y: center.y))
            bell.addCurve(to: CGPoint(x: center.x + size, y: center.y),
                          control1: CGPoint(x: center.x - size * 0.9, y: center.y + size * 1.5),
                          control2: CGPoint(x: center.x + size * 0.9, y: center.y + size * 1.5))
            bell.addCurve(to: CGPoint(x: center.x - size, y: center.y),
                          control1: CGPoint(x: center.x + size * 0.5, y: center.y - size * 0.34),
                          control2: CGPoint(x: center.x - size * 0.5, y: center.y - size * 0.34))
            context.addPath(bell)
            context.setFillColor(palette.cgColor(at: tone, alpha: 0.3))
            context.fillPath()
            context.addPath(bell)
            context.setStrokeColor(palette.cgColor(at: tone + 0.1, alpha: 0.9))
            context.setLineWidth(size * 0.05)
            context.strokePath()
            // Tentacles
            context.setLineCap(.round)
            for index in 0..<rng.int(in: 7...16) {
                let offset = size * (CGFloat(index) / 8 - 1) * 0.9
                context.setStrokeColor(palette.cgColor(at: tone, alpha: rng.cg(0.25...0.7)))
                context.setLineWidth(size * rng.cg(0.02...0.06))
                var point = CGPoint(x: center.x + offset, y: center.y)
                context.move(to: point)
                for step in 1...9 {
                    let sway = sin(CGFloat(step) * 0.9 + offset) * size * 0.16
                    point = CGPoint(x: point.x + sway * 0.4, y: point.y - size * 0.28)
                    context.addLine(to: point)
                }
                context.strokePath()
            }
            context.restoreGState()
        }
        ArtToolkit.speckle(in: context, rect: rect, rng: &rng, count: Int(rect.width * 0.7),
                           maxRadius: rect.width * 0.003, palette: Palette(hex: [0xFFFFFF, 0xAEE8FF]),
                           blend: .plusLighter, alphaRange: 0.1...0.6)
    }

    // MARK: - Abstract

    private static func stainedGlass(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                     _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        context.setFillColor(palette.cgColor(at: 0.98))
        context.fill(rect)
        let lead = CGColor(gray: 0.05, alpha: 0.95)
        let cells = ArtToolkit.jitteredLattice(rect: rect, columns: rng.int(in: 8...16),
                                               rows: rng.int(in: 6...12), jitter: 0.34, rng: &rng)
        for cell in cells {
            let centroid = ArtToolkit.centroid(of: cell)
            let nx = Double(centroid.x / rect.width), ny = Double(centroid.y / rect.height)
            let tone = clamp(noise.fbm(nx * 3.2, ny * 3.2, octaves: 3) * 0.5 + 0.5, 0, 1)
            ArtToolkit.fill(polygon: cell, in: context,
                            color: palette.cgColor(at: tone, alpha: 0.95),
                            stroke: lead, lineWidth: rect.width * 0.005)
            // Inner facet so a single pane still has structure.
            let inner = cell.map { point -> CGPoint in
                CGPoint(x: centroid.x + (point.x - centroid.x) * 0.62,
                        y: centroid.y + (point.y - centroid.y) * 0.62)
            }
            ArtToolkit.fill(polygon: inner, in: context,
                            color: palette.cgColor(at: clamp(tone + 0.18, 0, 1), alpha: 0.5))
        }
        // Rosette.
        let center = rect.center
        let radius = min(rect.width, rect.height) * rng.cg(0.14...0.26)
        let petals = rng.int(in: 8...16)
        for index in 0..<petals {
            let angle = CGFloat(index) / CGFloat(petals) * .pi * 2
            let tip = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let left = CGPoint(x: center.x + cos(angle + 0.4) * radius * 0.55,
                               y: center.y + sin(angle + 0.4) * radius * 0.55)
            let right = CGPoint(x: center.x + cos(angle - 0.4) * radius * 0.55,
                                y: center.y + sin(angle - 0.4) * radius * 0.55)
            ArtToolkit.fill(polygon: [center, left, tip, right], in: context,
                            color: palette.cgColor(at: rng.double(in: 0.1...0.9), alpha: 0.95),
                            stroke: lead, lineWidth: rect.width * 0.004)
        }
        ArtToolkit.radialGlow(in: context, center: center, radius: radius * 2.4,
                              color: CGColor(red: 1, green: 0.95, blue: 0.8, alpha: 0.25))
    }

    private static func mosaic(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                               _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        context.setFillColor(CGColor(gray: 0.12, alpha: 1))
        context.fill(rect)
        let columns = rng.int(in: 34...62)
        let rows = max(6, Int(CGFloat(columns) * rect.height / rect.width))
        let cells = ArtToolkit.jitteredLattice(rect: rect, columns: columns, rows: rows,
                                               jitter: 0.16, rng: &rng)
        let swirl = rng.double(in: 1.6...4.2)
        for cell in cells {
            let centroid = ArtToolkit.centroid(of: cell)
            let nx = Double(centroid.x / rect.width), ny = Double(centroid.y / rect.height)
            let base = noise.warped(nx * swirl, ny * swirl, strength: 1.4, octaves: 5) * 0.5 + 0.5
            // Contrast-stretch the field and jitter each tile, otherwise large
            // areas collapse into a single colour and the puzzle is unsolvable.
            let stretched = clamp((base - 0.5) * 1.9 + 0.5, 0, 1)
            let accent = rng.chance(0.08) ? rng.double(in: 0...1) : stretched
            let tone = clamp(accent + rng.double(in: -0.13...0.13), 0, 1)
            let shrunk = cell.map { point -> CGPoint in
                CGPoint(x: centroid.x + (point.x - centroid.x) * 0.86,
                        y: centroid.y + (point.y - centroid.y) * 0.86)
            }
            ArtToolkit.fill(polygon: shrunk, in: context, color: palette.cgColor(at: tone, alpha: 1))
        }
    }

    private static func lowPoly(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        let columns = rng.int(in: 14...26)
        let rows = max(5, Int(CGFloat(columns) * rect.height / rect.width))
        let cells = ArtToolkit.jitteredLattice(rect: rect, columns: columns, rows: rows,
                                               jitter: 0.44, rng: &rng)
        let frequency = rng.double(in: 1.8...3.6)
        for cell in cells {
            // Split every quad into two triangles so adjacent facets differ.
            let triangles = [[cell[0], cell[1], cell[2]], [cell[0], cell[2], cell[3]]]
            for triangle in triangles {
                let centroid = ArtToolkit.centroid(of: triangle)
                let nx = Double(centroid.x / rect.width)
                let ny = 1 - Double(centroid.y / rect.height)
                let tone = clamp(ny * 0.55 + (noise.fbm(nx * frequency, ny * frequency, octaves: 4) * 0.5 + 0.5) * 0.45,
                                 0, 1)
                ArtToolkit.fill(polygon: triangle, in: context,
                                color: palette.cgColor(at: tone, alpha: 1))
            }
        }
    }

    private static func julia(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                              _ rng: inout SplitMix64) {
        // Constants chosen near the boundary of the Mandelbrot set, where Julia
        // sets are richest in filament detail — exactly what a puzzle wants.
        let angle = rng.double(in: 0...(.pi * 2))
        let radius = rng.double(in: 0.72...0.79)
        let cx = cos(angle) * radius, cy = sin(angle) * radius
        let zoom = rng.double(in: 1.1...1.9)
        let maxIterations = 96

        let (w, h) = fieldSize(rect, divisor: 2.0)
        let field = ScalarField.generate(width: w, height: h) { u, v in
            var zx = (u - 0.5) * 3.2 / zoom
            var zy = (v - 0.5) * 3.2 / zoom * Double(rect.height / rect.width)
            var iteration = 0
            while zx * zx + zy * zy <= 16, iteration < maxIterations {
                let temp = zx * zx - zy * zy + cx
                zy = 2 * zx * zy + cy
                zx = temp
                iteration += 1
            }
            guard iteration < maxIterations else { return 1 }
            // Smooth (continuous) escape time removes iteration banding.
            let magnitude = (zx * zx + zy * zy).squareRoot()
            let smooth = Double(iteration) + 1 - log(log(max(magnitude, 1.0000001))) / log(2)
            // Escape counts cluster near zero; the power curve spreads the
            // exterior across the whole ramp instead of leaving it near-black.
            return clamp(pow(smooth / Double(maxIterations), 0.32), 0, 0.97)
        }
        ArtToolkit.drawField(field, palette: palette, in: context, rect: rect)
    }

    private static func marble(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                               _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        let frequency = rng.double(in: 3.5...9.0)
        let turbulence = rng.double(in: 3.0...8.0)
        let angle = rng.double(in: 0...(.pi))
        let (w, h) = fieldSize(rect, divisor: 2.2)
        var field = ScalarField.generate(width: w, height: h) { x, y in
            let u = x * cos(angle) + y * sin(angle)
            let t = noise.warped(x * 2.4, y * 2.4, strength: 1.6, octaves: 6)
            return sin(u * frequency * .pi + t * turbulence) * 0.5 + 0.5
        }
        field.normalize()
        ArtToolkit.drawField(field, palette: palette, in: context, rect: rect)
        // Gold veining.
        ArtToolkit.flowStrokes(in: context, rect: rect, noise: noise, rng: &rng,
                               palette: Palette(hex: [0xF6D98A, 0xB0873A]),
                               count: Int(rect.width * 0.25), steps: 30, frequency: 2.6,
                               blend: .normal, widthScale: 0.7)
    }

    private static func silk(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                             _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        let (w, h) = fieldSize(rect, divisor: 2.4)
        let field = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.warped(x * 2.0, y * 2.0, strength: 1.8, octaves: 6) * 0.5 + 0.5, 0, 1)
        }
        ArtToolkit.drawField(field, palette: palette, in: context, rect: rect)
        ArtToolkit.flowStrokes(in: context, rect: rect, noise: noise, rng: &rng, palette: palette,
                               count: Int(rect.width * 1.6), steps: 34, frequency: 2.0,
                               blend: .plusLighter)
        ArtToolkit.flowStrokes(in: context, rect: rect, noise: PerlinNoise(seed: rng.next()),
                               rng: &rng, palette: palette, count: Int(rect.width * 0.8),
                               steps: 24, frequency: 3.4, blend: .softLight, widthScale: 2.2)
    }

    private static func crystalCave(_ context: CGContext, _ rect: CGRect, _ palette: Palette,
                                    _ noise: PerlinNoise, _ rng: inout SplitMix64) {
        let (w, h) = fieldSize(rect, divisor: 2.8)
        let walls = ScalarField.generate(width: w, height: h) { x, y in
            clamp(noise.ridged(x * 3.4, y * 3.4, octaves: 6) * 0.9, 0, 1)
        }
        ArtToolkit.drawField(walls, palette: palette, in: context, rect: rect)

        // Prisms shooting from the floor, the ceiling and the walls.
        for _ in 0..<rng.int(in: 28...60) {
            let fromFloor = rng.chance(0.55)
            let base = CGPoint(x: rng.cg(rect.minX...rect.maxX),
                               y: fromFloor ? rect.minY + rng.cg(0...0.1) * rect.height
                                            : rect.maxY - rng.cg(0...0.1) * rect.height)
            let length = rect.height * rng.cg(0.12...0.46)
            let width = length * rng.cg(0.08...0.22)
            let lean = rng.cg(-0.35...0.35)
            let tip = CGPoint(x: base.x + lean * length, y: base.y + (fromFloor ? length : -length))
            let tone = rng.double(in: 0.25...0.85)
            let polygon = [CGPoint(x: base.x - width, y: base.y),
                           CGPoint(x: base.x + width, y: base.y),
                           CGPoint(x: tip.x + width * 0.18, y: tip.y),
                           CGPoint(x: tip.x - width * 0.18, y: tip.y)]
            ArtToolkit.fill(polygon: polygon, in: context,
                            color: palette.cgColor(at: tone, alpha: 0.88),
                            stroke: palette.cgColor(at: clamp(tone - 0.3, 0, 1), alpha: 0.9),
                            lineWidth: rect.width * 0.0016)
            // Specular edge.
            context.saveGState()
            context.setBlendMode(.plusLighter)
            context.setStrokeColor(palette.cgColor(at: clamp(tone + 0.25, 0, 1), alpha: 0.6))
            context.setLineWidth(width * 0.28)
            context.move(to: CGPoint(x: base.x - width * 0.35, y: base.y))
            context.addLine(to: CGPoint(x: tip.x - width * 0.05, y: tip.y))
            context.strokePath()
            context.restoreGState()
        }
        for _ in 0..<rng.int(in: 2...5) {
            ArtToolkit.radialGlow(in: context, center: rng.point(in: rect),
                                  radius: rect.width * rng.cg(0.1...0.28),
                                  color: palette.cgColor(at: rng.double(in: 0.4...0.8), alpha: 0.3))
        }
    }
}
