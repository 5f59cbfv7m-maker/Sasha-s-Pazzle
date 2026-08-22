import CoreGraphics
import Foundation
import Testing
@testable import JigsawPuzzle

@Suite("Puzzle geometry")
struct GeometryTests {

    private func geometry(columns: Int = 8, rows: Int = 6,
                          aspect: CGFloat = 1.5, seed: UInt64 = 0xBEEF) -> PuzzleGeometry {
        PuzzleGeometry(columns: columns, rows: rows, aspect: aspect, seed: seed)
    }

    // MARK: Grid selection

    @Test("Grid lands near the requested piece count", arguments: [12, 24, 48, 80, 150, 300, 500, 800])
    func gridMatchesTarget(target: Int) {
        for aspect in [CGFloat(0.6), 1.0, 1.5, 1.78] {
            let grid = PuzzleGeometry.grid(targetPieces: target, aspect: aspect)
            let count = grid.columns * grid.rows
            #expect(grid.columns >= 2 && grid.rows >= 2)
            #expect(abs(count - target) <= max(4, target / 8),
                    "aspect \(aspect): got \(count) for target \(target)")
        }
    }

    @Test("Cells stay close to square")
    func cellsAreNearlySquare() {
        for target in [12, 48, 200, 800] {
            for aspect in [CGFloat(0.66), 1.0, 1.5, 1.78] {
                let grid = PuzzleGeometry.grid(targetPieces: target, aspect: aspect)
                let geometry = PuzzleGeometry(columns: grid.columns, rows: grid.rows,
                                              aspect: aspect, seed: 1)
                let cellAspect = geometry.cellSize.width / geometry.cellSize.height
                #expect(cellAspect > 0.62 && cellAspect < 1.62,
                        "target \(target) aspect \(aspect) → cell aspect \(cellAspect)")
            }
        }
    }

    @Test("Board area is resolution independent")
    func boardAreaIsStable() {
        for aspect in [CGFloat(0.5), 1.0, 2.0] {
            let geometry = geometry(aspect: aspect)
            let area = geometry.boardSize.width * geometry.boardSize.height
            #expect(abs(area - PuzzleGeometry.referenceArea) < 1)
            #expect(abs(geometry.boardSize.aspect - aspect) < 0.001)
        }
    }

    // MARK: Shared edges

    @Test("Neighbouring pieces share an identical boundary")
    func adjacentEdgesMatchExactly() {
        let geometry = geometry(columns: 7, rows: 5, seed: 0x1234)

        for row in 0..<geometry.rows {
            for column in 0..<geometry.columns {
                let piece = geometry.index(row: row, column: column)
                let outline = geometry.outline(of: piece)

                if column < geometry.columns - 1 {
                    let neighbor = geometry.index(row: row, column: column + 1)
                    // Our right edge must be the neighbour's left edge, reversed.
                    let mine = outline[1].sampled()
                    let theirs = geometry.outline(of: neighbor)[3].sampled().reversed()
                    #expect(mine.count == theirs.count)
                    for (a, b) in zip(mine, theirs) {
                        #expect(a.isApproximatelyEqual(to: b, tolerance: 1e-9),
                                "vertical seam mismatch at (\(row),\(column)): \(a) vs \(b)")
                    }
                }

                if row < geometry.rows - 1 {
                    let neighbor = geometry.index(row: row + 1, column: column)
                    let mine = outline[2].sampled()                     // our bottom, right→left
                    let theirs = geometry.outline(of: neighbor)[0].sampled().reversed()
                    for (a, b) in zip(mine, theirs) {
                        #expect(a.isApproximatelyEqual(to: b, tolerance: 1e-9),
                                "horizontal seam mismatch at (\(row),\(column))")
                    }
                }
            }
        }
    }

    @Test("Outer border edges are perfectly straight")
    func borderEdgesAreFlat() {
        let geometry = geometry(columns: 6, rows: 4)
        for column in 0..<geometry.columns {
            let top = geometry.outline(of: geometry.index(row: 0, column: column))[0]
            for point in top.sampled() {
                #expect(abs(point.y) < 1e-9, "top border bulges at column \(column)")
            }
            let bottom = geometry.outline(of: geometry.index(row: geometry.rows - 1, column: column))[2]
            for point in bottom.sampled() {
                #expect(abs(point.y - geometry.boardSize.height) < 1e-9)
            }
        }
        for row in 0..<geometry.rows {
            let left = geometry.outline(of: geometry.index(row: row, column: 0))[3]
            for point in left.sampled() { #expect(abs(point.x) < 1e-9) }
            let right = geometry.outline(of: geometry.index(row: row, column: geometry.columns - 1))[1]
            for point in right.sampled() { #expect(abs(point.x - geometry.boardSize.width) < 1e-9) }
        }
    }

    @Test("Interior edges actually carry a tab")
    func interiorEdgesAreNotFlat() {
        let geometry = geometry(columns: 6, rows: 5)
        var tabbed = 0
        for row in 0..<(geometry.rows - 1) {
            for column in 0..<geometry.columns {
                guard let cut = geometry.horizontalCut(row: row, column: column) else { continue }
                let baseline = cut.start.y
                let excursion = cut.sampled().map { abs($0.y - baseline) }.max() ?? 0
                if excursion > geometry.tabAmplitude * 0.5 { tabbed += 1 }
            }
        }
        #expect(tabbed == (geometry.rows - 1) * geometry.columns,
                "every interior cut should have a real tab")
    }

    // MARK: Path quality

    @Test("Piece outlines are closed and free of self-intersections")
    func outlinesAreWellFormed() {
        let geometry = geometry(columns: 5, rows: 4, seed: 0xC0DE)
        for piece in 0..<geometry.pieceCount {
            let points = geometry.outline(of: piece).flatMap { $0.sampled(perSegment: 10) }
            #expect(points.count > 40)
            #expect(points.first!.isApproximatelyEqual(to: points.last!, tolerance: 1e-6),
                    "piece \(piece) outline is not closed")
            #expect(!selfIntersects(points), "piece \(piece) outline crosses itself")
        }
    }

    @Test("Piece bounds never exceed the tab reach")
    func boundsStayWithinOverhang() {
        let geometry = geometry(columns: 6, rows: 5)
        for piece in 0..<geometry.pieceCount {
            let bounds = geometry.localBounds(of: piece)
            let overhang = geometry.maximumOverhang + 2
            #expect(bounds.minX >= -overhang && bounds.minY >= -overhang)
            #expect(bounds.maxX <= geometry.cellSize.width + overhang)
            #expect(bounds.maxY <= geometry.cellSize.height + overhang)
        }
    }

    @Test("The same seed always produces the same cut")
    func geometryIsDeterministic() {
        let a = PuzzleGeometry(columns: 9, rows: 7, aspect: 1.4, seed: 777)
        let b = PuzzleGeometry(columns: 9, rows: 7, aspect: 1.4, seed: 777)
        let c = PuzzleGeometry(columns: 9, rows: 7, aspect: 1.4, seed: 778)
        #expect(a.outline(of: 20)[1].sampled() == b.outline(of: 20)[1].sampled())
        #expect(a.outline(of: 20)[1].sampled() != c.outline(of: 20)[1].sampled())
    }

    @Test("Solved cells tile the board exactly")
    func cellsTileTheBoard() {
        let geometry = geometry(columns: 8, rows: 6)
        var area: CGFloat = 0
        for piece in 0..<geometry.pieceCount { area += geometry.cellFrame(of: piece).width * geometry.cellFrame(of: piece).height }
        #expect(abs(area - PuzzleGeometry.referenceArea) < 0.001)

        // Neighbours' cells touch with no gap.
        for row in 0..<geometry.rows {
            for column in 0..<(geometry.columns - 1) {
                let left = geometry.cellFrame(of: geometry.index(row: row, column: column))
                let right = geometry.cellFrame(of: geometry.index(row: row, column: column + 1))
                #expect(abs(left.maxX - right.minX) < 1e-9)
            }
        }
    }

    @Test("Neighbour lookup is symmetric and bounded")
    func neighborsAreConsistent() {
        let geometry = geometry(columns: 5, rows: 4)
        for piece in 0..<geometry.pieceCount {
            let neighbors = geometry.neighbors(of: piece)
            #expect(neighbors.count >= 2 && neighbors.count <= 4)
            for neighbor in neighbors {
                #expect(geometry.neighbors(of: neighbor).contains(piece))
            }
        }
    }

    // MARK: Helpers

    /// Brute-force check for crossing segments.
    ///
    /// Concatenating the four edge samplings repeats each corner point, so the
    /// polyline is first de-duplicated; pairs that merely touch at a shared
    /// vertex are skipped, since only a genuine crossing is a defect.
    private func selfIntersects(_ points: [CGPoint]) -> Bool {
        var closed: [CGPoint] = []
        for point in points where !(closed.last?.isApproximatelyEqual(to: point, tolerance: 1e-7) ?? false) {
            closed.append(point)
        }
        if let first = closed.first, let last = closed.last,
           first.isApproximatelyEqual(to: last, tolerance: 1e-7) {
            closed.removeLast()
        }
        let count = closed.count
        guard count > 3 else { return false }

        for i in 0..<count {
            let a1 = closed[i], a2 = closed[(i + 1) % count]
            for j in stride(from: i + 2, to: count, by: 1) where !(i == 0 && j == count - 1) {
                let b1 = closed[j], b2 = closed[(j + 1) % count]
                let touches = [a1, a2].contains { corner in
                    corner.isApproximatelyEqual(to: b1, tolerance: 1e-7)
                        || corner.isApproximatelyEqual(to: b2, tolerance: 1e-7)
                }
                if !touches, segmentsCross(a1, a2, b1, b2) { return true }
            }
        }
        return false
    }

    private func segmentsCross(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> Bool {
        func orientation(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Int {
            let value = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y)
            if abs(value) < 1e-12 { return 0 }
            return value > 0 ? 1 : -1
        }
        let o1 = orientation(p1, p2, p3), o2 = orientation(p1, p2, p4)
        let o3 = orientation(p3, p4, p1), o4 = orientation(p3, p4, p2)
        return o1 != o2 && o3 != o4
    }
}
