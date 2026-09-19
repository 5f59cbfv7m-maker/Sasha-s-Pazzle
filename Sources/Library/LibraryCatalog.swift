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

    static var count: Int { items.count }

    /// The daily puzzle is always played at this size.
    static let dailyPieces = 150

    /// One built-in picture per calendar day.
    static func dailyItem(on date: Date = .now) -> LibraryItem {
        let items = builtIn()
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return items[day % items.count]
    }

    static func identifier(family: ArtFamily, variant: Int) -> String {
        "gen.\(family.rawValue).\(variant)"
    }

    /// The built-in pictures: photographs from `Resources/Pictures/` first, then
    /// the generated selection. Nothing is decoded here — bundled files only
    /// have their header read — so the library screen appears instantly and
    /// the bitmaps are produced lazily as cells scroll into view.
    static func builtIn() -> [LibraryItem] { items }

    /// Built once: the list is pure, and the profile asks for it on every layout pass.
    private static let items: [LibraryItem] = bundled() +
        selection.map { family, variant in
            LibraryItem(
                id: identifier(family: family, variant: variant),
                title: family.title,
                category: family.category,
                source: .generated(family: family, seed: family.seed(variant: variant)),
                addedAt: .distantPast,
                aspect: family.preferredAspect)
        }

    /// Photographs dropped into `Resources/Pictures/`. The file name carries
    /// the metadata — `sea_Sunset Beach.jpg` is category `sea`, title
    /// "Sunset Beach" — and the title is looked up in the string catalog so it
    /// can be translated. Unparseable names are skipped, not crashed on.
    static func bundled(in bundle: Bundle = .main) -> [LibraryItem] {
        ["jpg", "jpeg", "png", "heic"]
            .flatMap { bundle.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
            .compactMap(bundledItem(at:))
            .sorted { $0.id < $1.id }
    }

    static func bundledItem(at url: URL) -> LibraryItem? {
        let stem = url.deletingPathExtension().lastPathComponent
        guard let split = stem.firstIndex(of: "_"),
              let category = ArtCategory(rawValue: String(stem[..<split])),
              let size = ImagePipeline.dimensions(url: url), size.height > 0
        else { return nil }
        let title = String(stem[stem.index(after: split)...])
        return LibraryItem(
            id: "bundled.\(stem)",
            title: String(localized: String.LocalizationValue(title)),
            category: category,
            source: .bundled(fileName: url.lastPathComponent),
            addedAt: .distantPast,
            aspect: size.width / size.height)
    }
}
