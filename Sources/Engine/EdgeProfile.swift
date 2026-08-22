import CoreGraphics
import Foundation

/// One cubic Bézier segment. The start point is implied by the previous segment.
nonisolated struct CubicSegment: Sendable, Equatable {
    var control1: CGPoint
    var control2: CGPoint
    var end: CGPoint

    init(_ control1: CGPoint, _ control2: CGPoint, _ end: CGPoint) {
        self.control1 = control1
        self.control2 = control2
        self.end = end
    }
}

/// A chain of cubic segments with an explicit start point.
nonisolated struct EdgeCurve: Sendable, Equatable {
    var start: CGPoint
    var segments: [CubicSegment]

    var end: CGPoint { segments.last?.end ?? start }

    /// The same curve traversed in the opposite direction.
    ///
    /// This is *exact* — the control points are simply mirrored within each
    /// segment and the chain order flipped — which is what guarantees that two
    /// neighbouring pieces share one identical boundary with no gap or overlap.
    var reversed: EdgeCurve {
        guard !segments.isEmpty else { return self }
        var points: [CGPoint] = [start]
        points.reserveCapacity(segments.count + 1)
        for segment in segments { points.append(segment.end) }

        var flipped: [CubicSegment] = []
        flipped.reserveCapacity(segments.count)
        for index in stride(from: segments.count - 1, through: 0, by: -1) {
            let segment = segments[index]
            flipped.append(CubicSegment(segment.control2, segment.control1, points[index]))
        }
        return EdgeCurve(start: end, segments: flipped)
    }

    /// Samples the curve, including the start point, for tests and hit-testing.
    func sampled(perSegment: Int = 16) -> [CGPoint] {
        var points: [CGPoint] = [start]
        var current = start
        for segment in segments {
            for step in 1...perSegment {
                let t = CGFloat(step) / CGFloat(perSegment)
                points.append(Self.evaluate(current, segment.control1, segment.control2, segment.end, t))
            }
            current = segment.end
        }
        return points
    }

    static func evaluate(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                       y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }
}

/// The randomised shape of a single interior cut between two pieces.
///
/// The profile is defined once, in a normalised frame that runs from `(0, 0)` to
/// `(1, 0)`, with the tab bulging toward `+y` measured in *tab units*. Mapping it
/// into board space needs only a start point, an end point and an amplitude, so
/// both pieces sharing the cut derive their boundary from the very same numbers.
///
/// Shape anatomy (tab pointing up):
/// ```
///                ___
///               /   \      <- head   (half-width `headHalfWidth`, apex ~1.03 * height)
///              |     |
///   ___________\     /__________   <- neck (half-width `neckHalfWidth`, undercut)
///   ^ baseline                     <- gently bowed, never perfectly straight
/// ```
/// `headHalfWidth > neckHalfWidth` produces the undercut that makes a real
/// jigsaw piece lock into its neighbour instead of sliding out.
nonisolated struct EdgeProfile: Sendable, Equatable, Codable {
    /// `+1` — tab points toward the "positive" neighbour (right / below); `-1` — a socket.
    var polarity: Int8
    /// Position of the tab along the edge, `0...1`.
    var center: Double
    /// Half-width of the narrow neck, as a fraction of edge length.
    var neckHalfWidth: Double
    /// Half-width of the wide head, as a fraction of edge length. Must exceed the neck.
    var headHalfWidth: Double
    /// Tab height in tab units (≈1 by design, jittered for variety).
    var height: Double
    /// Left/right asymmetry of the tab, `-0.3...0.3`.
    var skew: Double
    /// Gentle bow of the two flat runs, in tab units.
    var bow1: Double, bow2: Double, bow3: Double, bow4: Double

    static func random(using rng: inout SplitMix64) -> EdgeProfile {
        EdgeProfile(
            polarity: rng.polarity(),
            center: rng.double(in: 0.455...0.545),
            neckHalfWidth: rng.double(in: 0.086...0.104),
            headHalfWidth: rng.double(in: 0.146...0.174),
            height: rng.double(in: 0.92...1.10),
            skew: rng.double(in: -0.26...0.26),
            bow1: rng.double(in: -0.055...0.055),
            bow2: rng.double(in: -0.055...0.055),
            bow3: rng.double(in: -0.055...0.055),
            bow4: rng.double(in: -0.055...0.055)
        )
    }

    /// The five cubic segments of the profile in normalised `(u, v)` space,
    /// where `u ∈ [0, 1]` runs along the edge and `v` is measured in tab units.
    ///
    /// `v` is returned *unsigned* (tab toward `+v`); polarity is applied when the
    /// profile is mapped into board space.
    func normalizedSegments() -> [CubicSegment] {
        let t = center
        let w = neckHalfWidth
        let b = headHalfWidth
        let h = height

        // Asymmetry: widen one flank of the tab and narrow the other.
        let neckLeft = w * (1 + skew), neckRight = w * (1 - skew)
        let headLeft = b * (1 + skew * 0.5), headRight = b * (1 - skew * 0.5)

        let a = CGPoint(x: t - neckLeft, y: 0)            // neck root, left
        let c = CGPoint(x: t + neckRight, y: 0)           // neck root, right
        let h1 = CGPoint(x: t - headLeft, y: 0.60 * h)    // head corner, left
        let h2 = CGPoint(x: t + headRight, y: 0.60 * h)   // head corner, right

        // 1 — flat run into the neck, bowed slightly for a hand-cut look.
        let s1 = CubicSegment(CGPoint(x: a.x * 0.32, y: bow1),
                              CGPoint(x: a.x * 0.74, y: bow2),
                              a)
        // 2 — left neck. The first control point sits *inside* the tab, which is
        //     what carves the undercut; the second sweeps out under the head.
        let s2 = CubicSegment(CGPoint(x: a.x + neckLeft * 0.55, y: 0.06 * h),
                              CGPoint(x: h1.x - headLeft * 0.18, y: 0.30 * h),
                              h1)
        // 3 — head. Controls stay within the head corners so the dome never
        //     bulges wider than `headHalfWidth` and cannot cross the necks.
        let s3 = CubicSegment(CGPoint(x: h1.x + headLeft * 0.22, y: 1.18 * h),
                              CGPoint(x: h2.x - headRight * 0.22, y: 1.18 * h),
                              h2)
        // 4 — right neck, mirror of 2.
        let s4 = CubicSegment(CGPoint(x: h2.x + headRight * 0.18, y: 0.30 * h),
                              CGPoint(x: c.x - neckRight * 0.55, y: 0.06 * h),
                              c)
        // 5 — flat run out of the neck.
        let s5 = CubicSegment(CGPoint(x: c.x + (1 - c.x) * 0.26, y: bow3),
                              CGPoint(x: c.x + (1 - c.x) * 0.68, y: bow4),
                              CGPoint(x: 1, y: 0))

        return [s1, s2, s3, s4, s5]
    }

    /// Maps the profile onto a board-space edge.
    ///
    /// - Parameters:
    ///   - start: canonical start of the cut (left end of a horizontal cut, top
    ///     end of a vertical cut).
    ///   - end: canonical end of the cut.
    ///   - normal: unit vector pointing toward the "positive" neighbour.
    ///   - amplitude: length of one tab unit in board points.
    func curve(from start: CGPoint, to end: CGPoint, normal: CGPoint, amplitude: CGFloat) -> EdgeCurve {
        let along = end - start
        let sign = CGFloat(polarity)

        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: start.x + along.x * p.x + normal.x * p.y * amplitude * sign,
                    y: start.y + along.y * p.x + normal.y * p.y * amplitude * sign)
        }

        let segments = normalizedSegments().map {
            CubicSegment(map($0.control1), map($0.control2), map($0.end))
        }
        return EdgeCurve(start: start, segments: segments)
    }
}
