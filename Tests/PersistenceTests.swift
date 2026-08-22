import CoreGraphics
import Foundation
import Testing
@testable import JigsawPuzzle

@Suite("Persistence and serialisation")
struct PersistenceTests {

    private func temporaryDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "JigsawTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sampleSnapshot(id: String = "game-1") -> GameSnapshot {
        var state = PuzzleState(columns: 6, rows: 4, cellSize: CGSize(width: 50, height: 50))
        var rng = SplitMix64(seed: 3)
        state.shuffleTray(using: &rng)
        state.placeFromTray(0, translation: .zero)
        let group = state.placeFromTray(1, translation: CGPoint(x: 3, y: 3))
        _ = state.settle(group: group, tolerance: 20)

        return GameSnapshot(id: id, itemID: "gen.0.3", itemTitle: "Nebula 4",
                            source: .generated(family: .nebula, seed: 12), imageAspect: 1.5,
                            puzzleAspect: .landscape32, targetPieces: 24, columns: 6, rows: 4,
                            seed: 0xABCDEF, elapsed: 91.5, state: state,
                            updatedAt: .now, isComplete: false)
    }

    @Test("A snapshot survives a JSON round trip unchanged")
    func snapshotRoundTrip() throws {
        let original = sampleSnapshot()
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(GameSnapshot.self, from: data)

        #expect(restored.id == original.id)
        #expect(restored.seed == original.seed)
        #expect(restored.columns == original.columns && restored.rows == original.rows)
        #expect(abs(restored.elapsed - original.elapsed) < 0.001)
        #expect(restored.state == original.state)
        #expect(restored.state.group(of: 1)?.members.sorted() == [0, 1])
        #expect(restored.source == original.source)
    }

    @Test("Saving, loading and deleting games")
    func saveStoreLifecycle() throws {
        let store = SaveStore(directory: try temporaryDirectory())
        #expect(store.load().isEmpty)

        try store.save(sampleSnapshot(id: "a"))
        try store.save(sampleSnapshot(id: "b"))
        #expect(store.load().count == 2)

        // Saving the same id replaces rather than duplicates.
        try store.save(sampleSnapshot(id: "a"))
        #expect(store.load().count == 2)
        #expect(store.load().first?.id == "a", "most recent first")

        try store.delete(id: "a")
        #expect(store.load().map(\.id) == ["b"])

        try store.deleteAll()
        #expect(store.load().isEmpty)
    }

    @Test("The archive is capped so it cannot grow without bound")
    func saveStoreRespectsLimit() throws {
        let store = SaveStore(directory: try temporaryDirectory())
        for index in 0..<10 {
            try store.save(sampleSnapshot(id: "game-\(index)"), limit: 4)
        }
        #expect(store.load().count == 4)
        #expect(store.load().first?.id == "game-9")
    }

    @Test("A corrupt file degrades to an empty list instead of crashing")
    func corruptArchiveIsIgnored() throws {
        let directory = try temporaryDirectory()
        try Data("not json at all".utf8).write(to: directory.appending(path: "savedGames.json"))
        let store = SaveStore(directory: directory)
        #expect(store.load().isEmpty)
    }

    @Test("Geometry regenerates identically from a restored seed")
    func geometryRebuildsFromSnapshot() throws {
        let snapshot = sampleSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(GameSnapshot.self, from: data)

        let original = PuzzleGeometry(columns: snapshot.columns, rows: snapshot.rows,
                                      aspect: 1.5, seed: snapshot.seed)
        let rebuilt = PuzzleGeometry(columns: restored.columns, rows: restored.rows,
                                     aspect: 1.5, seed: restored.seed)
        for piece in 0..<original.pieceCount {
            #expect(original.outline(of: piece)[1].sampled() == rebuilt.outline(of: piece)[1].sampled())
        }
    }

    @Test("Library items round trip, including their source")
    func libraryItemRoundTrip() throws {
        let items = [
            LibraryItem(id: "gen.5.2", title: "Canyon 3", category: .mountains,
                        source: .generated(family: .canyon, seed: 9),
                        addedAt: .distantPast, aspect: 1.5),
            LibraryItem(id: "user.abc.jpg", title: "Holiday", category: .mine,
                        source: .imported(fileName: "abc.jpg"), addedAt: .now, aspect: 0.75)
        ]
        let data = try JSONEncoder().encode(items)
        let restored = try JSONDecoder().decode([LibraryItem].self, from: data)
        #expect(restored == items)
        #expect(restored[1].isUserPhoto)
        #expect(!restored[0].isUserPhoto)
    }

    @Test("The built-in catalogue has 500+ unique pictures")
    func catalogueIsLargeAndUnique() {
        let items = LibraryCatalog.builtIn()
        #expect(items.count == ArtFamily.libraryCount)
        #expect(items.count >= 500)
        #expect(Set(items.map(\.id)).count == items.count)
        // Every category is represented.
        for category in ArtCategory.allCases where category != .mine {
            #expect(items.contains { $0.category == category }, "no pictures for \(category)")
        }
    }
}
