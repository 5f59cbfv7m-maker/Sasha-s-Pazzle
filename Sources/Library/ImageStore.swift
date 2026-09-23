import CoreGraphics
import Foundation

/// Central supplier of pixels, with an in-memory LRU on top of a disk cache.
///
/// Decoding and cropping a full-size photo is expensive the first time and cheap
/// afterwards: the master bitmap is written to `Caches` as JPEG at the size the
/// board needs, so re-opening a picture — or relaunching the app — costs one
/// small decode. Nothing here ever touches the network; the whole library works
/// on a plane.
actor ImageStore {
    static let shared = ImageStore()

    struct Request: Hashable, Sendable {
        var item: LibraryItem
        var aspect: PuzzleAspect
        var longSide: Int
    }

    private var memory: [Request: RenderedImage] = [:]
    private var order: [Request] = []
    private var inFlight: [Request: Task<RenderedImage?, Never>] = [:]
    private let memoryLimit = 240

    private nonisolated let cacheDirectory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        let url = base.appending(path: "PuzzleImages", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Returns the bitmap for a request, generating or decoding it if needed.
    /// Concurrent callers asking for the same picture share one task.
    func image(_ request: Request) async -> RenderedImage? {
        if let cached = memory[request] {
            touch(request)
            return cached
        }
        if let existing = inFlight[request] { return await existing.value }

        let directory = cacheDirectory
        let task = Task.detached(priority: .utility) { Self.produce(request, cacheDirectory: directory) }
        inFlight[request] = task
        let result = await task.value
        inFlight[request] = nil
        if let result { store(result, for: request) }
        return result
    }

    /// Drops cached derivatives of a picture the user deleted.
    func forget(itemID: String) {
        for request in order where request.item.id == itemID {
            memory[request] = nil
        }
        order.removeAll { $0.item.id == itemID }
    }

    func purgeMemory() {
        memory.removeAll()
        order.removeAll()
    }

    private func touch(_ request: Request) {
        order.removeAll { $0 == request }
        order.append(request)
    }

    private func store(_ image: RenderedImage, for request: Request) {
        memory[request] = image
        touch(request)
        while order.count > memoryLimit, let oldest = order.first {
            order.removeFirst()
            memory[oldest] = nil
        }
    }

    // MARK: - Production (off the actor)

    private nonisolated static func produce(_ request: Request, cacheDirectory: URL) -> RenderedImage? {
        let cacheURL = cacheDirectory.appending(path: cacheName(for: request))
        if FileManager.default.fileExists(atPath: cacheURL.path(percentEncoded: false)),
           let cached = try? ImagePipeline.decode(url: cacheURL, maxPixelSize: request.longSide) {
            return cached
        }

        let produced: RenderedImage?
        switch request.item.source {
        case let .imported(fileName):
            produced = decode(PhotoLibraryStore.photoURL(fileName: fileName), for: request)
        case let .bundled(fileName):
            produced = decode(Bundle.main.url(forResource: fileName, withExtension: nil), for: request)
        }

        if let produced, request.longSide >= 700 {
            // Only masters are worth caching on disk; thumbnails regenerate fast.
            try? ImagePipeline.write(produced, to: cacheURL, quality: 0.9)
        }
        return produced
    }

    private nonisolated static func decode(_ url: URL?, for request: Request) -> RenderedImage? {
        guard let url, let decoded = try? ImagePipeline.decode(url: url, maxPixelSize: request.longSide)
        else { return nil }
        return ImagePipeline.crop(decoded, toAspect: request.aspect.ratio)
    }

    private nonisolated static func cacheName(for request: Request) -> String {
        let key = "\(request.item.id)-\(request.aspect.rawValue)-\(request.longSide)"
        return "\(key.replacingOccurrences(of: "/", with: "_")).jpg"
    }
}
