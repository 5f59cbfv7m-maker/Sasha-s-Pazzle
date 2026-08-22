import CoreGraphics
import Foundation
import simd

/// A colour ramp sampled by position, the tonal identity of every generated image.
nonisolated struct Palette: Sendable {
    struct Stop: Sendable {
        var position: Double
        var color: SIMD3<Double>
    }

    var stops: [Stop]

    init(_ stops: [Stop]) {
        self.stops = stops.sorted { $0.position < $1.position }
    }

    /// Builds a ramp from evenly spaced hex colours.
    init(hex values: [UInt32]) {
        let count = max(1, values.count - 1)
        self.init(values.enumerated().map { index, hex in
            Stop(position: Double(index) / Double(count), color: Palette.unpack(hex))
        })
    }

    static func unpack(_ hex: UInt32) -> SIMD3<Double> {
        SIMD3(Double((hex >> 16) & 0xFF) / 255,
              Double((hex >> 8) & 0xFF) / 255,
              Double(hex & 0xFF) / 255)
    }

    func color(at position: Double) -> SIMD3<Double> {
        guard let first = stops.first else { return .zero }
        if position <= first.position { return first.color }
        guard let last = stops.last else { return first.color }
        if position >= last.position { return last.color }

        for index in 1..<stops.count where position <= stops[index].position {
            let a = stops[index - 1], b = stops[index]
            let span = b.position - a.position
            let t = span > 0 ? (position - a.position) / span : 0
            let smooth = t * t * (3 - 2 * t)
            return a.color + (b.color - a.color) * smooth
        }
        return last.color
    }

    func cgColor(at position: Double, alpha: CGFloat = 1) -> CGColor {
        let rgb = color(at: position)
        return CGColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: alpha)
    }

    /// Rotates hue and nudges saturation/brightness so one base palette yields a
    /// whole family of distinct-looking variants from different seeds.
    func varied(hueShift: Double, saturation: Double, brightness: Double) -> Palette {
        Palette(stops.map { stop in
            var hsv = Palette.toHSV(stop.color)
            hsv.x = (hsv.x + hueShift).truncatingRemainder(dividingBy: 1)
            if hsv.x < 0 { hsv.x += 1 }
            hsv.y = clamp(hsv.y * saturation, 0, 1)
            hsv.z = clamp(hsv.z * brightness, 0, 1)
            return Stop(position: stop.position, color: Palette.toRGB(hsv))
        })
    }

    static func toHSV(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        let maxValue = max(rgb.x, rgb.y, rgb.z), minValue = min(rgb.x, rgb.y, rgb.z)
        let delta = maxValue - minValue
        var hue = 0.0
        if delta > 0 {
            if maxValue == rgb.x { hue = ((rgb.y - rgb.z) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxValue == rgb.y { hue = (rgb.z - rgb.x) / delta + 2 }
            else { hue = (rgb.x - rgb.y) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return SIMD3(hue, maxValue > 0 ? delta / maxValue : 0, maxValue)
    }

    static func toRGB(_ hsv: SIMD3<Double>) -> SIMD3<Double> {
        let h = hsv.x * 6, s = hsv.y, v = hsv.z
        let i = floor(h)
        let f = h - i
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch Int(i) % 6 {
        case 0: return SIMD3(v, t, p)
        case 1: return SIMD3(q, v, p)
        case 2: return SIMD3(p, v, t)
        case 3: return SIMD3(p, q, v)
        case 4: return SIMD3(t, p, v)
        default: return SIMD3(v, p, q)
        }
    }
}
