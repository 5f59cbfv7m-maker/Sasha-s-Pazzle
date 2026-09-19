import Foundation
import Testing
@testable import JigsawPuzzle

@Suite("Player statistics")
@MainActor
struct StatsTests {

    private func temporaryDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "JigsawTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func daily(daysAgo: Int, elapsed: TimeInterval = 600) -> SolvedRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let item = LibraryCatalog.dailyItem(on: date)
        return SolvedRecord(itemID: item.id, category: item.category, pieces: 150,
                            targetPieces: LibraryCatalog.dailyPieces, elapsed: elapsed,
                            date: date, isUserPhoto: false)
    }

    @Test("The streak counts consecutive daily puzzles and survives a reload")
    func streak() throws {
        let directory = try temporaryDirectory()
        let stats = PlayerStats(directory: directory)
        #expect(stats.streak == 0)

        // Yesterday and the day before, today still open: the streak stands at 2.
        stats.record(daily(daysAgo: 1))
        stats.record(daily(daysAgo: 2))
        #expect(stats.streak == 2)
        #expect(!stats.dailySolvedToday)

        // A gap three days back breaks the chain.
        stats.record(daily(daysAgo: 4))
        #expect(stats.streak == 2)

        stats.record(daily(daysAgo: 0))
        #expect(stats.streak == 3)
        #expect(stats.dailySolvedToday)

        let reloaded = PlayerStats(directory: directory)
        #expect(reloaded.streak == 3)
        #expect(reloaded.puzzlesSolved == 4)
    }

    @Test("Finishing a game reports new achievements and the previous best time")
    func completionSummary() throws {
        let stats = PlayerStats(directory: try temporaryDirectory())
        let first = stats.record(daily(daysAgo: 0, elapsed: 900))
        #expect(first.newAchievements == [.firstPuzzle])
        #expect(first.previousBest == nil)

        let second = stats.record(daily(daysAgo: 0, elapsed: 240))
        #expect(second.previousBest == 900)
        // 150 pieces in four minutes is a sprint.
        #expect(second.newAchievements == [.sprinter])
        #expect(stats.bestTime(for: LibraryCatalog.dailyItem().id) == 240)
    }

    @Test("A category achievement needs every built-in picture of that category")
    func categoryAchievement() throws {
        let stats = PlayerStats(directory: try temporaryDirectory())
        let sea = LibraryCatalog.builtIn().filter { $0.category == .sea }
        for item in sea.dropLast() {
            stats.record(SolvedRecord(itemID: item.id, category: .sea, pieces: 24, targetPieces: 24,
                                      elapsed: 100, date: .now, isUserPhoto: false))
        }
        #expect(!Achievement.sea.isUnlocked(in: stats))
        let summary = stats.record(SolvedRecord(itemID: sea.last!.id, category: .sea, pieces: 24,
                                                targetPieces: 24, elapsed: 100, date: .now,
                                                isUserPhoto: false))
        #expect(summary.newAchievements.contains(.sea))
        #expect(stats.weeklyPieces.count == 12)
        #expect(stats.weeklyPieces.last == 24 * sea.count)
    }
}
