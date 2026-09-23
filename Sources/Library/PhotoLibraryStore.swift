import Foundation
import Observation
import SwiftUI

/// The picture library: built-in generated art plus the user's own photos.
///
/// Photos are stored as optimised JPEG copies inside the app container and
/// indexed by a small JSON manifest. Two deliberate choices:
///
/// * The originals are *copied*, not referenced — a puzzle keeps working after
///   the user deletes the photo from Photos or unplugs a drive.
/// * Bitmaps never live in the index. The manifest holds identifiers and
///   metadata only, so loading the library is a few kilobytes of JSON.
@Observable
final class PhotoLibraryStore {

    private(set) var builtIn: [LibraryItem] = LibraryCatalog.builtIn()
    private(set) var userItems: [LibraryItem] = []
    private(set) var lastError: String?

    var all: [LibraryItem] { userItems + builtIn }

    nonisolated static let containerDirectory: URL = {
        #if DEBUG
        if StageSandbox.isActive { return StageSandbox.directory }
        #endif
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        let url = base.appending(path: "JigsawPuzzle", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    nonisolated static let photosDirectory: URL = {
        let url = containerDirectory.appending(path: "Photos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static var manifestURL: URL { containerDirectory.appending(path: "library.json") }

    nonisolated static func photoURL(fileName: String) -> URL? {
        let url = photosDirectory.appending(path: fileName)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    init() { load() }

    // MARK: - Queries

    func items(in category: ArtCategory?) -> [LibraryItem] {
        guard let category else { return all }
        return category == .mine ? userItems : builtIn.filter { $0.category == category }
    }

    func item(id: String) -> LibraryItem? { all.first { $0.id == id } }

    // MARK: - Import

    /// Largest edge kept for an imported photo. Enough for a 800-piece board on a
    /// 6K display, small enough that a library of photos stays reasonable on disk.
    static let importMaxPixelSize = 4096

    @discardableResult
    func importPhoto(data: Data, suggestedTitle: String?) -> LibraryItem? {
        do {
            let decoded = try ImagePipeline.decode(data: data, maxPixelSize: Self.importMaxPixelSize)
            return try store(decoded, title: suggestedTitle)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func importPhoto(url: URL) -> LibraryItem? {
        // Files picked outside the container need a security scope on macOS.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let decoded = try ImagePipeline.decode(url: url, maxPixelSize: Self.importMaxPixelSize)
            return try store(decoded, title: url.deletingPathExtension().lastPathComponent)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func store(_ image: RenderedImage, title: String?) throws -> LibraryItem {
        let fileName = "\(UUID().uuidString).jpg"
        let url = Self.photosDirectory.appending(path: fileName)
        try ImagePipeline.write(image, to: url, quality: 0.92)
        let item = LibraryItem(
            id: "user.\(fileName)",
            title: title?.isEmpty == false ? title! : String(localized: "My Photo"),
            category: .mine,
            source: .imported(fileName: fileName),
            addedAt: .now,
            aspect: image.aspect)
        userItems.insert(item, at: 0)
        save()
        return item
    }

    func rename(_ item: LibraryItem, to title: String) {
        guard let index = userItems.firstIndex(where: { $0.id == item.id }) else { return }
        userItems[index].title = title
        save()
    }

    func delete(_ item: LibraryItem) {
        guard case let .imported(fileName) = item.source else { return }
        try? FileManager.default.removeItem(at: Self.photosDirectory.appending(path: fileName))
        userItems.removeAll { $0.id == item.id }
        save()
        let id = item.id
        Task { await ImageStore.shared.forget(itemID: id) }
    }

    // MARK: - Persistence

    private struct Manifest: Codable {
        var version = 1
        var items: [LibraryItem]
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return }
        // Drop entries whose backing file vanished (container restored, disk full…).
        userItems = manifest.items.filter {
            guard case let .imported(fileName) = $0.source else { return false }
            return Self.photoURL(fileName: fileName) != nil
        }
        if userItems.count != manifest.items.count { save() }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(Manifest(items: userItems))
            try data.write(to: Self.manifestURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
