import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A decoded bitmap ready to be cut into pieces or shown as a thumbnail.
///
/// `CGImage` is immutable once created, so passing it between isolation domains
/// is safe; the wrapper states that intent instead of scattering `@unchecked`
/// annotations through the code base.
nonisolated struct RenderedImage: @unchecked Sendable {
    let cgImage: CGImage

    var width: Int { cgImage.width }
    var height: Int { cgImage.height }
    var size: CGSize { CGSize(width: width, height: height) }
    var aspect: CGFloat { height > 0 ? CGFloat(width) / CGFloat(height) : 1 }
}

/// Decoding, cropping and encoding helpers built on ImageIO.
///
/// Everything goes through downsampled decoding: a 48-megapixel photo is never
/// fully materialised in memory, which is what keeps a 800-piece puzzle from a
/// phone camera roll inside a sane memory budget.
nonisolated enum ImagePipeline {

    enum Failure: LocalizedError {
        case unreadable
        case unsupportedFormat
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadable: String(localized: "The image could not be read.")
            case .unsupportedFormat: String(localized: "This image format is not supported.")
            case .encodingFailed: String(localized: "The image could not be saved.")
            }
        }
    }

    /// Decodes an image scaled so its longest side is at most `maxPixelSize`.
    static func decode(url: URL, maxPixelSize: Int) throws -> RenderedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw Failure.unreadable }
        return try decode(source: source, maxPixelSize: maxPixelSize)
    }

    static func decode(data: Data, maxPixelSize: Int) throws -> RenderedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw Failure.unreadable }
        return try decode(source: source, maxPixelSize: maxPixelSize)
    }

    private static func decode(source: CGImageSource, maxPixelSize: Int) throws -> RenderedImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honours EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.unsupportedFormat
        }
        return RenderedImage(cgImage: image)
    }

    /// Pixel dimensions without decoding the image.
    static func dimensions(url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        // Orientations 5–8 swap the axes.
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return orientation >= 5
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    /// Centre-crops to an aspect ratio. `nil` keeps the original framing, so the
    /// photo is never stretched and nothing is thrown away unless asked for.
    static func crop(_ image: RenderedImage, toAspect aspect: CGFloat?) -> RenderedImage {
        guard let aspect, aspect > 0 else { return image }
        let bounds = CGRect(origin: .zero, size: image.size)
        let target = bounds.centeredCrop(aspect: aspect).integralOutset(0)
        guard target.width >= 1, target.height >= 1,
              let cropped = image.cgImage.cropping(to: target) else { return image }
        return RenderedImage(cgImage: cropped)
    }

    /// Redraws at an exact pixel size (used to normalise puzzle source images).
    static func resize(_ image: RenderedImage, to size: CGSize) -> RenderedImage {
        guard size.width >= 1, size.height >= 1,
              let context = ArtToolkit.makeContext(size: size) else { return image }
        context.interpolationQuality = .high
        context.draw(image.cgImage, in: CGRect(origin: .zero, size: size))
        guard let output = context.makeImage() else { return image }
        return RenderedImage(cgImage: output)
    }

    static func write(_ image: RenderedImage, to url: URL,
                      type: UTType = .jpeg, quality: CGFloat = 0.92) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil) else { throw Failure.encodingFailed }
        CGImageDestinationAddImage(destination, image.cgImage,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed }
    }
}
