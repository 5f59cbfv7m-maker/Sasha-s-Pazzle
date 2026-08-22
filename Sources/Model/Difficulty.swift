import Foundation

/// Preset piece counts. The engine itself has no upper bound — the presets are
/// simply the curated rungs of the ladder, from a coffee-break puzzle to a
/// genuinely punishing 800-piece board.
nonisolated enum Difficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy, normal, hard, expert, master, insane, extreme, nightmare

    var id: String { rawValue }

    /// Target piece count. The real grid is chosen near this number so cells
    /// stay square for the image's aspect ratio.
    var targetPieces: Int {
        switch self {
        case .easy: 12
        case .normal: 24
        case .hard: 48
        case .expert: 80
        case .master: 150
        case .insane: 300
        case .extreme: 500
        case .nightmare: 800
        }
    }

    var title: String {
        switch self {
        case .easy: String(localized: "Easy")
        case .normal: String(localized: "Normal")
        case .hard: String(localized: "Hard")
        case .expert: String(localized: "Expert")
        case .master: String(localized: "Master")
        case .insane: String(localized: "Insane")
        case .extreme: String(localized: "Extreme")
        case .nightmare: String(localized: "Nightmare")
        }
    }

    var symbol: String {
        switch self {
        case .easy: "leaf"
        case .normal: "circle.grid.2x2"
        case .hard: "square.grid.3x3"
        case .expert: "square.grid.4x3.fill"
        case .master: "flame"
        case .insane: "bolt.fill"
        case .extreme: "tornado"
        case .nightmare: "skull"
        }
    }

    /// Rough guidance shown under the difficulty card.
    var estimate: String {
        switch self {
        case .easy: String(localized: "A few minutes")
        case .normal: String(localized: "10–20 minutes")
        case .hard: String(localized: "30–45 minutes")
        case .expert: String(localized: "About an hour")
        case .master: String(localized: "A couple of hours")
        case .insane: String(localized: "An evening")
        case .extreme: String(localized: "Several sittings")
        case .nightmare: String(localized: "A serious project")
        }
    }

    /// Presets above this line stress the renderer; used to warn and to pick
    /// rendering strategy defaults.
    var isHeavy: Bool { targetPieces >= 300 }

    static let bounds = 12...1000
}

/// How aggressively pieces jump into place.
nonisolated enum SnapAssist: String, CaseIterable, Codable, Identifiable, Sendable {
    case precise, standard, generous

    var id: String { rawValue }
    var multiplier: CGFloat {
        switch self {
        case .precise: 0.65
        case .standard: 1.0
        case .generous: 1.5
        }
    }
    var title: String {
        switch self {
        case .precise: String(localized: "Precise")
        case .standard: String(localized: "Standard")
        case .generous: String(localized: "Generous")
        }
    }
}

/// Aspect the source photo is cropped to before cutting.
nonisolated enum PuzzleAspect: String, CaseIterable, Codable, Identifiable, Sendable {
    case original, square, landscape32, landscape43, landscape169, portrait23

    var id: String { rawValue }

    /// `nil` keeps the photo's own aspect ratio — nothing is cropped away.
    var ratio: CGFloat? {
        switch self {
        case .original: nil
        case .square: 1
        case .landscape32: 3.0 / 2.0
        case .landscape43: 4.0 / 3.0
        case .landscape169: 16.0 / 9.0
        case .portrait23: 2.0 / 3.0
        }
    }

    var title: String {
        switch self {
        case .original: String(localized: "Original")
        case .square: "1:1"
        case .landscape32: "3:2"
        case .landscape43: "4:3"
        case .landscape169: "16:9"
        case .portrait23: "2:3"
        }
    }
}
