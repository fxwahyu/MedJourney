//
//  DownsampledImage.swift
//  MedJourney
//
//  Components — memory-efficient image thumbnails.
//
//  Rendering `Image(uiImage: UIImage(data: blob))` decodes the FULL-resolution
//  bitmap into memory (a 12 MP photo ≈ 48 MB) even when it's only shown at 120×160.
//  Re-decoding on every body re-evaluation and across page changes is the main
//  cause of the app's memory growth.
//
//  `DownsampledImage` instead uses ImageIO to decode directly at the display size,
//  caches the small result, and loads it off the main thread. Peak and steady-state
//  memory drop from tens of MB per image to a few hundred KB.
//

import SwiftUI
import ImageIO

// MARK: - Downsampler

enum ImageDownsampler {

    /// Bounded in-memory cache of already-downsampled thumbnails.
    /// NSCache auto-evicts under memory pressure, so it can't grow without limit.
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 32 * 1024 * 1024   // ~32 MB ceiling for decoded thumbnails
        return c
    }()

    /// Caps a picked/captured image to `maxDimension` on its long edge, decoding
    /// directly at that size via ImageIO — never materialising the full bitmap.
    ///
    /// Use at INGESTION time (photo picker / file import) so `uploadedImages` never
    /// holds a 12 MP original. 2000 px keeps Vision OCR and full-screen display sharp
    /// while cutting a 4032×3024 photo (~48 MB decoded) to ~3 MP (~12 MB). Not cached
    /// (these are one-off working images, not repeatedly-shown thumbnails).
    static func downsampled(from data: Data, maxDimension: CGFloat = 2000) -> UIImage? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cg)
    }

    /// Caps an already-decoded `UIImage` (e.g. from the camera) to `maxDimension` on
    /// its long edge by re-rendering at the smaller size; the full-res original is
    /// released by the caller. Returns the input unchanged if already small enough.
    static func downsampled(_ image: UIImage, maxDimension: CGFloat = 2000) -> UIImage {
        let longEdge = max(image.size.width, image.size.height)
        guard longEdge > maxDimension else { return image }
        let ratio = maxDimension / longEdge
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Decodes `data` directly at `pointSize` (× screen scale) without ever
    /// materialising the full-resolution bitmap. Results are cached by content + size.
    static func thumbnail(from data: Data, pointSize: CGSize, scale: CGFloat) -> UIImage? {
        let maxPixel = Int(max(pointSize.width, pointSize.height) * scale)
        let key = "\(data.count)-\(data.hashValue)-\(maxPixel)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key, cost: cg.bytesPerRow * cg.height)
        return image
    }
}

// MARK: - View

/// Loads and shows a downsampled thumbnail from raw image `Data`, off the main thread.
/// Use anywhere a stored image blob is shown at a fixed display size.
struct DownsampledImage<Placeholder: View>: View {

    let data: Data
    let size: CGSize
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: data) {
            // Skip if already loaded for this data.
            if image != nil { return }
            let scale = await screenScale()
            let decoded = await Task.detached(priority: .userInitiated) {
                ImageDownsampler.thumbnail(from: data, pointSize: size, scale: scale)
            }.value
            if !Task.isCancelled { image = decoded }
        }
    }

    @MainActor private func screenScale() -> CGFloat { UIScreen.main.scale }
}

extension DownsampledImage where Placeholder == Color {
    init(data: Data, size: CGSize) {
        self.init(data: data, size: size) { Color(.secondarySystemBackground) }
    }
}
