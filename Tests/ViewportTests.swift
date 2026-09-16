import CoreGraphics
import Foundation
import Testing
@testable import JigsawPuzzle

@Suite("Viewport and resizing")
struct ViewportTests {

    /// A table parked far to the right of a wide window — legal there, stranded
    /// once the window shrinks around it.
    private let table = CGRect(x: 0, y: 0, width: 200, height: 150)
    private let panned = Viewport(scale: 1, offset: CGSize(width: 900, height: 500))
    private let wide = CGSize(width: 1400, height: 900)
    private let narrow = CGSize(width: 400, height: 300)

    @Test("Screen and board mappings are exact inverses")
    func mappingRoundTrips() {
        let viewport = Viewport(scale: 1.065, offset: CGSize(width: 67.5, height: 24))
        for point in [CGPoint(x: 0, y: 0), CGPoint(x: 512.25, y: -88), CGPoint(x: -3, y: 1201.5)] {
            let round = viewport.board(viewport.screen(point))
            #expect(abs(round.x - point.x) < 1e-9)
            #expect(abs(round.y - point.y) < 1e-9)
        }
    }

    @Test("Clamping leaves a viewport that is already in reach alone")
    func clampIsIdempotentWhenVisible() {
        #expect(panned.clamped(content: table, viewSize: wide) == panned)
    }

    /// The bug behind `BoardInputController.handleResize`: only panning and
    /// zooming used to clamp, so shrinking the window left every piece outside
    /// the visible rect with no way back but "Fit".
    @Test("Shrinking the view pulls the table back into reach")
    func shrinkingClampsTheTableBack() {
        let visibleRect = CGRect(origin: .zero, size: narrow)
        #expect(!panned.screen(table).intersects(visibleRect))

        let fixed = panned.clamped(content: table, viewSize: narrow)
        let frame = fixed.screen(table)
        #expect(frame.intersects(visibleRect))

        // The clamp leaves at least the slack margin of content reachable.
        let slackX = max(narrow.width * 0.35, 80)
        let slackY = max(narrow.height * 0.35, 80)
        #expect(frame.minX <= narrow.width - slackX + 1e-9)
        #expect(frame.minY <= narrow.height - slackY + 1e-9)
    }

    @Test("A resize moves the board but never rescales it")
    func resizeKeepsTheZoom() {
        #expect(panned.clamped(content: table, viewSize: narrow).scale == panned.scale)
    }

    @Test("Zooming keeps the point under the cursor fixed")
    func zoomIsAnchored() {
        let anchor = CGPoint(x: 220, y: 140)
        let before = panned.board(anchor)
        let after = panned.zoomed(by: 2, around: anchor)
        #expect(abs(after.screen(before).x - anchor.x) < 1e-9)
        #expect(abs(after.screen(before).y - anchor.y) < 1e-9)
    }
}
