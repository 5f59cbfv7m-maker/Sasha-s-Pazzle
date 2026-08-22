import CoreGraphics
import Foundation

/// Deterministic 64-bit generator (SplitMix64).
///
/// Every visual aspect of a puzzle — edge shapes, shuffle order, procedural
/// artwork — must be exactly reproducible from a stored seed. That keeps saved
/// games tiny: we persist one `UInt64` instead of thousands of Bézier control
/// points, and it lets us regenerate identical geometry on any device.
nonisolated struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<1`.
    mutating func unit() -> Double { Double(next() >> 11) * 0x1.0p-53 }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    mutating func cg(_ range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(double(in: Double(range.lowerBound)...Double(range.upperBound)))
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        guard range.upperBound > range.lowerBound else { return range.lowerBound }
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func chance(_ probability: Double) -> Bool { unit() < probability }

    /// `+1` or `-1`, used for tab polarity.
    mutating func polarity() -> Int8 { unit() < 0.5 ? -1 : 1 }

    /// Uniform point inside `rect`.
    mutating func point(in rect: CGRect) -> CGPoint {
        CGPoint(x: cg(rect.minX...rect.maxX), y: cg(rect.minY...rect.maxY))
    }

    /// Fisher–Yates shuffle driven by this generator (so shuffles are reproducible).
    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var out = items
        guard out.count > 1 else { return out }
        for i in stride(from: out.count - 1, to: 0, by: -1) {
            out.swapAt(i, int(in: 0...i))
        }
        return out
    }
}

/// Mixes arbitrary integers into a well-distributed seed.
///
/// Used to derive a *per-edge* generator from `(puzzleSeed, kind, row, column)`
/// so that edge geometry can be produced in any order, in parallel, and still be
/// bit-for-bit identical between runs.
nonisolated func mixSeed(_ values: UInt64...) -> UInt64 {
    var h: UInt64 = 0xCBF2_9CE4_8422_2325
    for value in values {
        h = (h ^ value) &* 0x1000_0000_01B3
        h ^= h >> 29
        h = h &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 32
    }
    return h == 0 ? 0x9E37_79B9_7F4A_7C15 : h
}
