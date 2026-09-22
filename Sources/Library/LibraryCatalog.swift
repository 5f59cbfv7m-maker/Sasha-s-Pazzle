import Foundation

/// Builds the built-in picture library.
nonisolated enum LibraryCatalog {

    /// Generated pictures shipped alongside the photographs. Empty since the
    /// library switched to real photos (`Resources/Pictures/`); the generators
    /// stay so saved games of generated pictures still load, and a family can
    /// come back as `(.galaxy, 0)` — the variant is its seed.
    static let selection: [(family: ArtFamily, variant: Int)] = []

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
