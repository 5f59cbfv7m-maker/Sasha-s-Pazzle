import Foundation
import Observation
import SwiftUI

/// Application-level state: preferences, library, navigation and the live game.
@Observable
@MainActor
final class AppModel {

    enum Route: Hashable {
        case setup(itemID: String)
        case game
    }

    let settings = AppSettings()
    let library = PhotoLibraryStore()
    /// Shared so the menu bar can drive zoom and fit without reaching into views.
    let boardController = BoardInputController()

    var path: [Route] = []
    var showSettings = false
    private(set) var session: GameSession?
    private(set) var savedGames: [GameSnapshot] = []

    @ObservationIgnored private let saveStore = SaveStore()

    init() { refreshSaves() }

    var resumable: [GameSnapshot] { savedGames.filter { !$0.isComplete } }

    func refreshSaves() {
        savedGames = saveStore.load()
    }

    // MARK: - Navigation

    func openSetup(for item: LibraryItem) {
        path = [.setup(itemID: item.id)]
    }

    func showLibrary() {
        session?.saveNow()
        session?.textures.cancel()
        session = nil
        path = []
        refreshSaves()
    }

    func start(item: LibraryItem, aspect: PuzzleAspect, pieces: Int) {
        session?.saveNow()
        session?.textures.cancel()
        session = GameSession(item: item, aspect: aspect, targetPieces: pieces)
        path = [.game]
    }

    func resume(_ snapshot: GameSnapshot) {
        // A user photo may have been deleted since the game was saved.
        if case let .imported(fileName) = snapshot.source,
           PhotoLibraryStore.photoURL(fileName: fileName) == nil {
            delete(snapshot)
            return
        }
        session?.saveNow()
        session?.textures.cancel()
        session = GameSession(snapshot: snapshot)
        path = [.game]
    }

    func restartCurrent() {
        guard let current = session else { return }
        start(item: current.item, aspect: current.puzzleAspect, pieces: current.targetPieces)
    }

    // MARK: - Saves

    func delete(_ snapshot: GameSnapshot) {
        try? saveStore.delete(id: snapshot.id)
        refreshSaves()
    }

    func deleteAllSaves() {
        try? saveStore.deleteAll()
        refreshSaves()
    }

    // MARK: - Menu commands

    var canPlay: Bool { session != nil }

    func togglePause() {
        guard let session else { return }
        session.phase == .paused ? session.resume() : session.pause()
    }
}
