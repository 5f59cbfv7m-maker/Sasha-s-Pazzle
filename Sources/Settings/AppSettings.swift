import Foundation
import Observation
import SwiftUI

/// User preferences, mirrored into `UserDefaults` on every change.
@Observable
final class AppSettings {

    enum Appearance: String, CaseIterable, Identifiable, Sendable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: String(localized: "System")
            case .light: String(localized: "Light")
            case .dark: String(localized: "Dark")
            }
        }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    var appearance: Appearance { didSet { write(appearance.rawValue, "appearance") } }
    var soundEnabled: Bool { didSet { write(soundEnabled, "sound") } }
    var hapticsEnabled: Bool { didSet { write(hapticsEnabled, "haptics") } }
    /// Faint copy of the picture under the board — a guide, not a solution.
    var showGhostImage: Bool { didSet { write(showGhostImage, "ghost") } }
    var snapAssist: SnapAssist { didSet { write(snapAssist.rawValue, "snapAssist") } }
    var defaultDifficulty: Difficulty { didSet { write(defaultDifficulty.rawValue, "difficulty") } }
    var defaultAspect: PuzzleAspect { didSet { write(defaultAspect.rawValue, "aspect") } }
    /// Draw a thin outline around every piece; helps on busy pictures.
    var showPieceOutlines: Bool { didSet { write(showPieceOutlines, "outlines") } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        soundEnabled = defaults.object(forKey: "sound") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "haptics") as? Bool ?? true
        showGhostImage = defaults.object(forKey: "ghost") as? Bool ?? true
        snapAssist = SnapAssist(rawValue: defaults.string(forKey: "snapAssist") ?? "") ?? .standard
        defaultDifficulty = Difficulty(rawValue: defaults.string(forKey: "difficulty") ?? "") ?? .normal
        defaultAspect = PuzzleAspect(rawValue: defaults.string(forKey: "aspect") ?? "") ?? .original
        showPieceOutlines = defaults.object(forKey: "outlines") as? Bool ?? true
    }

    private func write(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }
}
