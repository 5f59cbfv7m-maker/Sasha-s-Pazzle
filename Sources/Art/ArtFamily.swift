import CoreGraphics
import Foundation

/// The generator families behind the built-in picture library.
///
/// Bundling several hundred real photographs is neither legal nor practical for
/// an offline app, so the library is *generated*: 29 families × 20 seeded
/// variants = 580 unique, reproducible, detail-rich pictures that cost a few
/// kilobytes of code instead of gigabytes of assets.
nonisolated enum ArtFamily: Int, CaseIterable, Codable, Sendable, Identifiable {
    // Space
    case nebula, galaxy, aurora, planetRise
    // Mountains
    case alpineRidge, canyon, dunes, iceField
    // Nature
    case forest, autumnWoods, meadow, tulipFields
    // Sea
    case ocean, sunsetBeach, coralReef, koiPond
    // City
    case cityNight, cityDusk, harbourLights
    // Animals
    case butterflies, flamingos, jellyfish
    // Abstract
    case stainedGlass, mosaic, lowPoly, juliaSet, marble, silkFlow, crystalCave

    var id: Int { rawValue }

    /// Seeded variants per family. 29 × 20 = 580 built-in pictures.
    static let variantsPerFamily = 20
    static var libraryCount: Int { allCases.count * variantsPerFamily }

    var category: ArtCategory {
        switch self {
        case .nebula, .galaxy, .aurora, .planetRise: .space
        case .alpineRidge, .canyon, .dunes, .iceField: .mountains
        case .forest, .autumnWoods, .meadow, .tulipFields: .nature
        case .ocean, .sunsetBeach, .coralReef, .koiPond: .sea
        case .cityNight, .cityDusk, .harbourLights: .city
        case .butterflies, .flamingos, .jellyfish: .animals
        case .stainedGlass, .mosaic, .lowPoly, .juliaSet, .marble, .silkFlow, .crystalCave: .abstract
        }
    }

    var title: String {
        switch self {
        case .nebula: String(localized: "Nebula")
        case .galaxy: String(localized: "Galaxy")
        case .aurora: String(localized: "Aurora")
        case .planetRise: String(localized: "Planetrise")
        case .alpineRidge: String(localized: "Alpine Ridge")
        case .canyon: String(localized: "Canyon")
        case .dunes: String(localized: "Dunes")
        case .iceField: String(localized: "Ice Field")
        case .forest: String(localized: "Forest")
        case .autumnWoods: String(localized: "Autumn Woods")
        case .meadow: String(localized: "Meadow")
        case .tulipFields: String(localized: "Tulip Fields")
        case .ocean: String(localized: "Ocean")
        case .sunsetBeach: String(localized: "Sunset Beach")
        case .coralReef: String(localized: "Coral Reef")
        case .koiPond: String(localized: "Koi Pond")
        case .cityNight: String(localized: "City Lights")
        case .cityDusk: String(localized: "City at Dusk")
        case .harbourLights: String(localized: "Harbour")
        case .butterflies: String(localized: "Butterflies")
        case .flamingos: String(localized: "Flamingos")
        case .jellyfish: String(localized: "Jellyfish")
        case .stainedGlass: String(localized: "Stained Glass")
        case .mosaic: String(localized: "Mosaic")
        case .lowPoly: String(localized: "Low Poly")
        case .juliaSet: String(localized: "Julia Set")
        case .marble: String(localized: "Marble")
        case .silkFlow: String(localized: "Silk")
        case .crystalCave: String(localized: "Crystal Cave")
        }
    }

    /// Natural aspect ratio the family is composed for.
    var preferredAspect: CGFloat {
        switch self {
        case .planetRise, .juliaSet, .mosaic, .stainedGlass: 1.0
        case .cityNight, .harbourLights, .alpineRidge, .dunes: 16.0 / 9.0
        default: 3.0 / 2.0
        }
    }

    /// Base colour ramp, ordered **top of canvas → bottom**.
    var basePalette: Palette {
        switch self {
        case .nebula: Palette(hex: [0x05030F, 0x1B0B3B, 0x5B1E7A, 0xC2437E, 0xFFB36B, 0x120A22])
        case .galaxy: Palette(hex: [0x02020A, 0x0B1740, 0x2F4C9B, 0x8FA8E8, 0xFFF2CC, 0x05040F])
        case .aurora: Palette(hex: [0x030711, 0x0A2A3B, 0x18C39A, 0x7DF9C4, 0x2A1B5E, 0x060A18])
        case .planetRise: Palette(hex: [0x00010A, 0x0A1230, 0x3C6BB0, 0xE8B96A, 0x8A3B2A, 0x02030B])
        case .alpineRidge: Palette(hex: [0x1D3A63, 0x4E7CB0, 0xA9C6E2, 0xF2E7DA, 0x8E9BAA, 0x2C3542])
        case .canyon: Palette(hex: [0x3A5C8C, 0xC98A5B, 0x9E4A2E, 0x6B2C21, 0xE8C79B, 0x33201B])
        case .dunes: Palette(hex: [0x2E4E7E, 0xE7B96F, 0xC98C4A, 0x8A5B2E, 0xF6E2BE, 0x5A3A1F])
        case .iceField: Palette(hex: [0x0B2038, 0x2E6C9E, 0x8FD3F4, 0xE9F7FF, 0xB9CEDD, 0x16283C])
        case .forest: Palette(hex: [0x0B1A12, 0x1E4429, 0x3E7C3A, 0x8FBF5A, 0xD9E8A8, 0x152018])
        case .autumnWoods: Palette(hex: [0x2A1409, 0x8A3B14, 0xD9782B, 0xF2B441, 0xFFE2A0, 0x3A1E0C])
        case .meadow: Palette(hex: [0x7EC8F0, 0xBFE4A8, 0x6FAE4A, 0xE8E15C, 0xF4A0C0, 0x2E4A22])
        case .tulipFields: Palette(hex: [0x9FD4F2, 0xE0574F, 0xF2A03C, 0xD94C7A, 0x5C8F3E, 0x2A3E20])
        case .ocean: Palette(hex: [0x9FDCEF, 0x2E8FBF, 0x0C4E77, 0x052B44, 0xE8F7FB, 0x03202F])
        case .sunsetBeach: Palette(hex: [0x2E2A5E, 0xE0655B, 0xF9A65C, 0xFFD79C, 0x6B4A6B, 0x1E1730])
        case .coralReef: Palette(hex: [0x0A4A6B, 0x1D8BA8, 0xF07E4C, 0xF2C14E, 0xE05A7A, 0x073243])
        case .koiPond: Palette(hex: [0x0D2A24, 0x1D5C4A, 0x3F9A72, 0xE8642F, 0xF5E7C6, 0x0A1C18])
        case .cityNight: Palette(hex: [0x050818, 0x121C3A, 0x2A3C6E, 0xF2C25C, 0xE85D3A, 0x03060F])
        case .cityDusk: Palette(hex: [0x2B2350, 0x6B4A7E, 0xD9756B, 0xF6B36A, 0x2E3350, 0x151228])
        case .harbourLights: Palette(hex: [0x061428, 0x123A5A, 0x2E7FA8, 0xF6D26A, 0xE8703A, 0x04101E])
        case .butterflies: Palette(hex: [0xF6E7C6, 0xE8A23C, 0xD9503C, 0x5B3A8C, 0x2E6BA8, 0x2A1E14])
        case .flamingos: Palette(hex: [0xF2D9C6, 0xF29CB0, 0xE05A78, 0xB03A5E, 0x3E7C7A, 0x22303A])
        case .jellyfish: Palette(hex: [0x02061A, 0x0B2A5E, 0x3C7ED9, 0xB08CF2, 0xF2A0C8, 0x03040E])
        case .stainedGlass: Palette(hex: [0x1B1030, 0xB03A5E, 0xE8A23C, 0x2E7FA8, 0x3E9A6B, 0x140C22])
        case .mosaic: Palette(hex: [0x0E2A3A, 0x1D6B8A, 0xE8C25C, 0xC9603A, 0x8A9A5B, 0x0A1C26])
        case .lowPoly: Palette(hex: [0x2B3A7E, 0x4E7CB0, 0xE8A23C, 0xD9503C, 0x3E9A6B, 0x1A2140])
        case .juliaSet: Palette(hex: [0x02030E, 0x1B2C6B, 0x3E8AC9, 0xF2E2A0, 0xE0643C, 0x0A0616])
        case .marble: Palette(hex: [0xF2EDE4, 0xD9CBB8, 0x8A7A66, 0x3E3A34, 0xC9A25B, 0x1E1B18])
        case .silkFlow: Palette(hex: [0x120A2A, 0x5B2E8C, 0xC94A9A, 0xF2A05C, 0x3E8AC9, 0x0A0618])
        case .crystalCave: Palette(hex: [0x0A1428, 0x1D4A7A, 0x5BC9E0, 0xB0F2E8, 0x8A5BC9, 0x060C18])
        }
    }

    /// How far a seed may shift the hue. Realistic scenes stay near their palette;
    /// abstract ones roam freely, which is what makes 20 variants feel different.
    var hueRange: Double {
        switch category {
        case .abstract: 0.5
        case .space: 0.28
        default: 0.09
        }
    }

    /// Palette for a given variant.
    func palette(variant: Int) -> Palette {
        var rng = SplitMix64(seed: mixSeed(UInt64(rawValue), 0xC0FFEE, UInt64(variant)))
        return basePalette.varied(hueShift: rng.double(in: -hueRange...hueRange),
                                  saturation: rng.double(in: 0.86...1.18),
                                  brightness: rng.double(in: 0.88...1.12))
    }

    /// Stable seed for `(family, variant)` — the identity of one library picture.
    func seed(variant: Int) -> UInt64 {
        mixSeed(0x5EED, UInt64(rawValue), UInt64(variant))
    }
}
