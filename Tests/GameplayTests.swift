import CoreGraphics
import Foundation
import Testing
@testable import JigsawPuzzle

@Suite("Placement, snapping and groups")
struct GameplayTests {

    private func makeState(columns: Int = 5, rows: Int = 4) -> PuzzleState {
        PuzzleState(columns: columns, rows: rows, cellSize: CGSize(width: 100, height: 100))
    }

    @Test("A fresh puzzle starts entirely in the tray")
    func freshStateIsInTray() {
        let state = makeState()
        #expect(state.trayOrder.count == 20)
        #expect(state.placedCount == 0)
        #expect(state.groups.isEmpty)
        #expect(!state.isComplete)
        #expect(state.origin(of: 0) == nil)
    }

    @Test("Coordinates follow the solved layout plus the group offset")
    func coordinatesAreOffsetBased() {
        var state = makeState()
        #expect(state.solvedOrigin(of: 6) == CGPoint(x: 100, y: 100))
        state.placeFromTray(6, translation: CGPoint(x: 25, y: -40))
        #expect(state.origin(of: 6) == CGPoint(x: 125, y: 60))
    }

    @Test("Dropping a piece near its neighbour snaps and joins")
    func snapJoinsNeighbours() {
        var state = makeState()
        state.placeFromTray(0, translation: .zero)
        let group = state.placeFromTray(1, translation: CGPoint(x: 6, y: -4))

        let outcome = state.settle(group: group, tolerance: 20)
        #expect(outcome.didSnap)
        #expect(outcome.didMerge)
        #expect(state.groups.count == 1)
        #expect(state.group(of: 1)?.members.sorted() == [0, 1])
        #expect(state.origin(of: 1) == CGPoint(x: 100, y: 0))
    }

    @Test("A piece dropped out of range stays where it was put")
    func farPieceDoesNotSnap() {
        var state = makeState()
        state.placeFromTray(0, translation: .zero)
        let group = state.placeFromTray(1, translation: CGPoint(x: 60, y: 55))

        let outcome = state.settle(group: group, tolerance: 20)
        #expect(!outcome.didSnap)
        #expect(state.groups.count == 2)
        #expect(state.group(of: 1)?.translation == CGPoint(x: 60, y: 55))
    }

    @Test("Non-adjacent pieces never merge, however close")
    func nonAdjacentPiecesDoNotMerge() {
        var state = makeState()
        state.placeFromTray(0, translation: .zero)
        let group = state.placeFromTray(2, translation: CGPoint(x: 1, y: 1))
        let outcome = state.settle(group: group, tolerance: 40)
        // It snaps home, but 0 and 2 are not neighbours so they stay separate.
        #expect(outcome.didSnap)
        #expect(!outcome.didMerge)
        #expect(state.groups.count == 2)
    }

    @Test("Moving one piece of a group moves the whole cluster")
    func groupsMoveTogether() {
        var state = makeState()
        state.placeFromTray(0, translation: .zero)
        let group = state.placeFromTray(1, translation: CGPoint(x: 4, y: 3))
        _ = state.settle(group: group, tolerance: 20)
        let merged = state.group(of: 0)!.id

        state.move(group: merged, by: CGPoint(x: 37, y: -12))
        #expect(state.origin(of: 0) == CGPoint(x: 37, y: -12))
        #expect(state.origin(of: 1) == CGPoint(x: 137, y: -12))
        #expect(state.groups.count == 1, "a group must never split while moving")
    }

    @Test("One piece can bridge four separate clusters at once")
    func bridgingPieceAbsorbsEveryNeighbour() {
        var state = makeState()
        // Leave a hole at piece 6 and surround it with four separate groups.
        for piece: Int32 in [1, 5, 7, 11] {
            state.placeFromTray(piece, translation: .zero)
        }
        #expect(state.groups.count == 4)

        let group = state.placeFromTray(6, translation: CGPoint(x: 3, y: -2))
        let outcome = state.settle(group: group, tolerance: 25)

        #expect(outcome.didSnap)
        #expect(outcome.absorbedGroups.count == 4)
        #expect(state.groups.count == 1)
        #expect(state.group(of: 6)?.members.count == 5)
    }

    @Test("Merging two multi-piece groups keeps every member")
    func groupToGroupMergeKeepsMembers() {
        var state = makeState()
        // Column pair 0/5 and column pair 1/6, then join them.
        state.placeFromTray(0, translation: CGPoint(x: 10, y: 10))
        var group = state.placeFromTray(5, translation: CGPoint(x: 10, y: 10))
        _ = state.settle(group: group, tolerance: 5)
        let left = state.group(of: 0)!.id
        #expect(state.groups[left]?.members.count == 2)

        state.placeFromTray(1, translation: CGPoint(x: 200, y: 200))
        group = state.placeFromTray(6, translation: CGPoint(x: 200, y: 200))
        _ = state.settle(group: group, tolerance: 5)
        let right = state.group(of: 1)!.id
        #expect(state.groups[right]?.members.count == 2)

        state.setTranslation(CGPoint(x: 14, y: 8), forGroup: right)
        let outcome = state.settle(group: right, tolerance: 20)
        #expect(outcome.didMerge)
        #expect(state.groups.count == 1)
        #expect(state.groups.values.first?.members.sorted() == [0, 1, 5, 6])
        // Relative positions survive the merge.
        #expect(state.origin(of: 1)! - state.origin(of: 0)! == CGPoint(x: 100, y: 0))
        #expect(state.origin(of: 5)! - state.origin(of: 0)! == CGPoint(x: 0, y: 100))
    }

    @Test("Completion needs every piece in one cluster")
    func completionDetection() {
        var state = makeState(columns: 3, rows: 2)
        #expect(!state.isComplete)
        for piece in state.trayOrder {
            state.placeFromTray(piece, translation: .zero)
        }
        #expect(!state.isComplete, "placed but not yet joined")

        var absorbed = 0
        for id in state.groups.keys.sorted() {
            let outcome = state.settle(group: id, tolerance: 1)
            absorbed += outcome.absorbedGroups.count
        }
        #expect(state.groups.count == 1)
        #expect(state.isComplete)
        #expect(absorbed > 0)
    }

    @Test("solveAll finishes any size of puzzle")
    func solveAllCompletes() {
        for (columns, rows) in [(4, 3), (8, 6), (25, 20)] {
            var state = PuzzleState(columns: columns, rows: rows,
                                    cellSize: CGSize(width: 40, height: 40))
            state.solveAll()
            #expect(state.isComplete, "\(columns)x\(rows) did not complete")
            #expect(state.groups.values.first?.members.count == columns * rows)
        }
    }

    @Test("A piece can be sent back to the tray")
    func returnToTray() {
        var state = makeState()
        state.placeFromTray(3, translation: .zero)
        #expect(state.placedCount == 1)
        state.returnToTray(3)
        #expect(state.placedCount == 0)
        #expect(state.groups.isEmpty)
        #expect(state.trayOrder.contains(3))
    }

    @Test("Snap tolerance scales with piece size and zoom")
    func snapToleranceScales() {
        let big = PuzzleState(columns: 4, rows: 3, cellSize: CGSize(width: 200, height: 200))
        let small = PuzzleState(columns: 40, rows: 30, cellSize: CGSize(width: 20, height: 20))
        #expect(big.snapTolerance(viewScale: 1) > small.snapTolerance(viewScale: 1))

        // Zoomed out, the radius grows in board units so it feels constant on screen.
        #expect(small.snapTolerance(viewScale: 0.25) > small.snapTolerance(viewScale: 4))
        // …but never beyond half a cell, or pieces would grab the wrong slot.
        #expect(small.snapTolerance(viewScale: 0.01) <= small.cellSize.minimumSide * 0.55)

        let generous = small.snapTolerance(viewScale: 1, assist: SnapAssist.generous.multiplier)
        let precise = small.snapTolerance(viewScale: 1, assist: SnapAssist.precise.multiplier)
        #expect(generous >= precise)
    }

    @Test("Shuffle is random but reproducible from its seed")
    func shuffleIsSeeded() {
        var a = makeState(columns: 10, rows: 8)
        var b = makeState(columns: 10, rows: 8)
        var c = makeState(columns: 10, rows: 8)
        var rngA = SplitMix64(seed: 99), rngB = SplitMix64(seed: 99), rngC = SplitMix64(seed: 100)
        let identity = a.trayOrder
        a.shuffleTray(using: &rngA)
        b.shuffleTray(using: &rngB)
        c.shuffleTray(using: &rngC)

        #expect(a.trayOrder == b.trayOrder, "same seed must reproduce the shuffle")
        #expect(a.trayOrder != c.trayOrder, "different seeds must differ")
        #expect(a.trayOrder != identity, "the order must actually change")
        #expect(Set(a.trayOrder) == Set(identity), "no piece may be lost or duplicated")
    }

    @Test("Scattering empties the tray and keeps pieces on the table")
    func scatterFillsTheTable() {
        var state = makeState(columns: 8, rows: 6)
        let board = CGRect(x: 0, y: 0, width: 800, height: 600)
        let table = board.insetBy(dx: -400, dy: -300)
        var rng = SplitMix64(seed: 5)
        state.scatterTray(in: table, avoiding: board, using: &rng)

        #expect(state.trayOrder.isEmpty)
        #expect(state.placedCount == 48)
        #expect(state.groups.count == 48, "scattered pieces must not auto-join")
        for piece in Int32(0)..<48 {
            let origin = state.origin(of: piece)!
            #expect(table.insetBy(dx: -200, dy: -200).contains(origin))
        }
    }

    @Test("Structure revision tracks joins but not plain movement")
    func structureRevisionOnlyTracksStructure() {
        var state = makeState()
        state.placeFromTray(0, translation: .zero)
        let group = state.placeFromTray(1, translation: CGPoint(x: 2, y: 2))
        let before = state.structureRevision
        state.move(group: group, by: CGPoint(x: 5, y: 5))
        #expect(state.structureRevision == before, "moving must not invalidate the draw order")
        _ = state.settle(group: group, tolerance: 30)
        #expect(state.structureRevision > before, "merging must invalidate it")
    }
}
