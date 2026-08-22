import CoreGraphics
import Foundation

nonisolated extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }
    static func += (lhs: inout CGPoint, rhs: CGPoint) { lhs = lhs + rhs }

    var magnitude: CGFloat { (x * x + y * y).squareRoot() }
    func distance(to other: CGPoint) -> CGFloat { (self - other).magnitude }
    var asSize: CGSize { CGSize(width: x, height: y) }

    func isApproximatelyEqual(to other: CGPoint, tolerance: CGFloat = 1e-6) -> Bool {
        abs(x - other.x) <= tolerance && abs(y - other.y) <= tolerance
    }
}

nonisolated extension CGSize {
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize { CGSize(width: lhs.width * rhs, height: lhs.height * rhs) }
    var aspect: CGFloat { height > 0 ? width / height : 1 }
    var asPoint: CGPoint { CGPoint(x: width, y: height) }
    var minimumSide: CGFloat { Swift.min(width, height) }
}

nonisolated extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
    func offsetBy(_ point: CGPoint) -> CGRect { offsetBy(dx: point.x, dy: point.y) }

    /// Largest sub-rect of `self` with the given aspect ratio, centred.
    func centeredCrop(aspect: CGFloat) -> CGRect {
        guard aspect > 0, width > 0, height > 0 else { return self }
        if width / height > aspect {
            let w = height * aspect
            return CGRect(x: midX - w / 2, y: minY, width: w, height: height)
        } else {
            let h = width / aspect
            return CGRect(x: minX, y: midY - h / 2, width: width, height: h)
        }
    }
}

nonisolated func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

/// Transports a CoreFoundation object across isolation domains.
///
/// `CGImage` and friends are immutable once created but are not formally
/// `Sendable`; this wrapper documents that the value is safe to hand off.
nonisolated struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
