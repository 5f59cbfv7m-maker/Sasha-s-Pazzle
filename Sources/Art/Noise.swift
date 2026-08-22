import Foundation
import simd

/// Classic Perlin gradient noise, seeded and reproducible.
///
/// Deliberately hand-rolled rather than pulled from a package: the whole point
/// of the generated library is that it is offline, dependency-free and produces
/// byte-identical pictures for a given seed on every device.
nonisolated struct PerlinNoise: Sendable {
    /// Owns the permutation table so the noise struct can carry a raw pointer.
    ///
    /// The lookup sits in the innermost loop of every generated picture. Reading
    /// it through a Swift `Array` costs a bounds check and retain/release per
    /// access, which an unoptimised debug build cannot elide — it made artwork
    /// generation ~70× slower than release. A manually managed buffer keeps the
    /// hot path a plain load in every configuration.
    private final class Table: @unchecked Sendable {
        let storage: UnsafeMutablePointer<Int32>

        init(seed: UInt64) {
            var rng = SplitMix64(seed: seed)
            var values = Array(Int32(0)...Int32(255))
            for index in stride(from: 255, to: 0, by: -1) {
                values.swapAt(index, rng.int(in: 0...index))
            }
            storage = UnsafeMutablePointer<Int32>.allocate(capacity: 512)
            for index in 0..<512 { storage[index] = values[index & 255] }
        }

        deinit { storage.deallocate() }
    }

    private let table: Table
    /// Borrowed from `table`, whose lifetime the struct keeps alive.
    private nonisolated(unsafe) let permutation: UnsafeMutablePointer<Int32>

    init(seed: UInt64) {
        table = Table(seed: seed)
        permutation = table.storage
    }

    @inline(__always)
    private static func fade(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }

    @inline(__always)
    private static func grad(_ hash: Int32, _ x: Double, _ y: Double) -> Double {
        switch hash & 7 {
        case 0: x + y
        case 1: -x + y
        case 2: x - y
        case 3: -x - y
        case 4: x
        case 5: -x
        case 6: y
        default: -y
        }
    }

    /// Noise in `-1...1`.
    @inline(__always)
    func value(_ x: Double, _ y: Double) -> Double {
        let xFloor = x.rounded(.down), yFloor = y.rounded(.down)
        let xi = Int(xFloor) & 255, yi = Int(yFloor) & 255
        let xf = x - xFloor, yf = y - yFloor
        let u = Self.fade(xf), v = Self.fade(yf)

        let a = Int(permutation[xi]) + yi
        let b = Int(permutation[xi + 1]) + yi
        let g00 = Self.grad(permutation[a], xf, yf)
        let g10 = Self.grad(permutation[b], xf - 1, yf)
        let g01 = Self.grad(permutation[a + 1], xf, yf - 1)
        let g11 = Self.grad(permutation[b + 1], xf - 1, yf - 1)

        let top = g00 + u * (g10 - g00)
        let bottom = g01 + u * (g11 - g01)
        return (top + v * (bottom - top)) * 1.4
    }

    /// Fractal Brownian motion — the workhorse for clouds, terrain and haze.
    @inline(__always)
    func fbm(_ x: Double, _ y: Double, octaves: Int = 5,
             lacunarity: Double = 2.03, gain: Double = 0.5) -> Double {
        var sum = 0.0, amplitude = 1.0, frequency = 1.0, norm = 0.0
        for _ in 0..<octaves {
            sum += value(x * frequency, y * frequency) * amplitude
            norm += amplitude
            amplitude *= gain
            frequency *= lacunarity
        }
        return norm > 0 ? sum / norm : 0
    }

    /// Ridged multifractal — sharp creases, ideal for mountain ridges and lightning.
    @inline(__always)
    func ridged(_ x: Double, _ y: Double, octaves: Int = 5, lacunarity: Double = 2.07) -> Double {
        var sum = 0.0, amplitude = 1.0, frequency = 1.0, norm = 0.0
        for _ in 0..<octaves {
            let n = 1 - abs(value(x * frequency, y * frequency))
            sum += n * n * amplitude
            norm += amplitude
            amplitude *= 0.52
            frequency *= lacunarity
        }
        return norm > 0 ? sum / norm : 0
    }

    /// Domain-warped fbm: feeds noise back into its own coordinates, producing
    /// the swirling filaments that make nebulae and marble look organic.
    func warped(_ x: Double, _ y: Double, strength: Double = 1.2, octaves: Int = 5) -> Double {
        let qx = fbm(x, y, octaves: 3)
        let qy = fbm(x + 5.2, y + 1.3, octaves: 3)
        return fbm(x + strength * qx, y + strength * qy, octaves: octaves)
    }
}

/// A scalar field sampled on a grid, used as the base layer of most artworks.
///
/// Rendering happens at a fraction of the final resolution and is then upsampled
/// with bicubic filtering: noise is smooth by nature, so the eye cannot tell,
/// and it turns a multi-second job into tens of milliseconds.
nonisolated struct ScalarField: Sendable {
    let width: Int
    let height: Int
    var samples: [Float]

    init(width: Int, height: Int, repeating value: Float = 0) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.samples = [Float](repeating: value, count: self.width * self.height)
    }

    /// Fills the field in parallel; `body` receives normalised `0...1` coordinates.
    /// Upper bound on the sampling grid. Noise is smooth, so beyond this the
    /// upsampled result is indistinguishable while the cost keeps growing.
    static let maximumSide = 560

    static func generate(width: Int, height: Int,
                         _ body: @Sendable (Double, Double) -> Double) -> ScalarField {
        let cap = Double(maximumSide) / Double(max(width, height, 1))
        let scale = min(1, cap)
        var field = ScalarField(width: max(8, Int(Double(width) * scale)),
                                height: max(8, Int(Double(height) * scale)))
        let w = field.width, h = field.height
        field.samples.withUnsafeMutableBufferPointer { buffer in
            let sendable = UncheckedSendable(buffer)
            DispatchQueue.concurrentPerform(iterations: h) { row in
                let uy = Double(row) / Double(h - 1 == 0 ? 1 : h - 1)
                let base = row * w
                for column in 0..<w {
                    let ux = Double(column) / Double(w - 1 == 0 ? 1 : w - 1)
                    sendable.value[base + column] = Float(body(ux, uy))
                }
            }
        }
        return field
    }

    mutating func normalize(to range: ClosedRange<Float> = 0...1) {
        guard let low = samples.min(), let high = samples.max(), high > low else { return }
        let scale = (range.upperBound - range.lowerBound) / (high - low)
        for index in samples.indices {
            samples[index] = range.lowerBound + (samples[index] - low) * scale
        }
    }
}
