import Foundation

/// Builds the built-in picture library.
nonisolated enum LibraryCatalog {

    static func identifier(family: ArtFamily, variant: Int) -> String {
        "gen.\(family.rawValue).\(variant)"
    }

    /// All 580 built-in pictures. Creating them is pure arithmetic — no I/O, no
    /// decoding — so the library screen appears instantly and the bitmaps are
    /// produced lazily as cells scroll into view.
    static func builtIn() -> [LibraryItem] {
        var items: [LibraryItem] = []
        items.reserveCapacity(ArtFamily.libraryCount)
        // Variant-major order: the first screenful shows one picture from every
        // family rather than twenty nebulae in a row.
        for variant in 0..<ArtFamily.variantsPerFamily {
            for family in ArtFamily.allCases {
                items.append(LibraryItem(
                    id: identifier(family: family, variant: variant),
                    title: "\(family.title) \(variant + 1)",
                    category: family.category,
                    source: .generated(family: family, seed: family.seed(variant: variant)),
                    addedAt: .distantPast,
                    aspect: family.preferredAspect))
            }
        }
        return items
    }
}
