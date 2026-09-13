import Foundation

/// Builds the built-in picture library.
nonisolated enum LibraryCatalog {

    /// The curated built-in set: one hand-picked seeded variant per family.
    /// The variant numbers are the seeds that looked best at full size — change
    /// them only after looking at the result, not by taste of the number.
    static let selection: [(family: ArtFamily, variant: Int)] = [
        // Space
        (.galaxy, 0), (.aurora, 3),
        // Mountains
        (.alpineRidge, 6), (.canyon, 3), (.dunes, 8), (.iceField, 6),
        // Nature
        (.forest, 1), (.autumnWoods, 6),
        // Sea
        (.sunsetBeach, 8), (.coralReef, 13), (.koiPond, 0),
        // City
        (.cityNight, 6), (.cityDusk, 2), (.harbourLights, 3),
        // Animals
        (.butterflies, 18), (.flamingos, 12), (.jellyfish, 12),
        // Abstract
        (.stainedGlass, 1), (.mosaic, 3), (.lowPoly, 18), (.juliaSet, 3),
        (.marble, 3), (.silkFlow, 7), (.crystalCave, 8),
    ]

    static var count: Int { selection.count }

    static func identifier(family: ArtFamily, variant: Int) -> String {
        "gen.\(family.rawValue).\(variant)"
    }

    /// The built-in pictures. Creating them is pure arithmetic — no I/O, no
    /// decoding — so the library screen appears instantly and the bitmaps are
    /// produced lazily as cells scroll into view.
    static func builtIn() -> [LibraryItem] {
        selection.map { family, variant in
            LibraryItem(
                id: identifier(family: family, variant: variant),
                title: family.title,
                category: family.category,
                source: .generated(family: family, seed: family.seed(variant: variant)),
                addedAt: .distantPast,
                aspect: family.preferredAspect)
        }
    }
}
