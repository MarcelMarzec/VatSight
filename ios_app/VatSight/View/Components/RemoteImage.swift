//
//  RemoteImage.swift
//  VatSight
//
//  Event banners: downloaded once (disk URL cache), downsampled to display size with ImageIO
//  off the main thread, and kept in a memory cache so scrolling back is instant.
//

import SwiftUI
import UIKit
import ImageIO

final class ImagePipeline {
    static let shared = ImagePipeline()

    private let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1024 * 1024 // decoded bytes
        return cache
    }()
    private var inFlight: [NSString: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "EventImages")
        configuration.urlCache = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 150 * 1024 * 1024, directory: directory)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    private func key(_ url: URL, _ maxPixelSize: CGFloat) -> NSString {
        "\(url.absoluteString)#\(Int(maxPixelSize))" as NSString
    }

    func cachedImage(for url: URL, maxPixelSize: CGFloat) -> UIImage? {
        memory.object(forKey: key(url, maxPixelSize))
    }

    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let key = key(url, maxPixelSize)
        if let cached = memory.object(forKey: key) { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let session = self.session
        let task = Task<UIImage?, Never> {
            await Self.download(url, maxPixelSize: maxPixelSize, session: session)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image, let cgImage = image.cgImage {
            memory.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        }
        return image
    }

    @concurrent
    private static func download(_ url: URL, maxPixelSize: CGFloat, session: URLSession) async -> UIImage? {
        guard let (data, response) = try? await session.data(from: url) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return downsample(data, maxPixelSize: maxPixelSize)
    }

    nonisolated private static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Async image with caching, a neutral placeholder and no layout jump (size it from outside).
struct RemoteImage: View {
    let url: URL?
    var maxPixelSize: CGFloat = 1200
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    /// The URL `image` was loaded from, so a changed URL on the same view reloads.
    @State private var imageURL: URL?
    @State private var didFail = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(url: URL?, maxPixelSize: CGFloat = 1200, contentMode: ContentMode = .fill) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.contentMode = contentMode
        let cached = url.flatMap { ImagePipeline.shared.cachedImage(for: $0, maxPixelSize: maxPixelSize) }
        _image = State(initialValue: cached)
        _imageURL = State(initialValue: cached == nil ? nil : url)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                if didFail || url == nil {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                imageURL = nil
                return
            }
            guard imageURL != url || image == nil else { return }
            if let cached = ImagePipeline.shared.cachedImage(for: url, maxPixelSize: maxPixelSize) {
                image = cached
                imageURL = url
                didFail = false
                return
            }
            let loaded = await ImagePipeline.shared.image(for: url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            if reduceMotion {
                image = loaded
            } else {
                withAnimation(.easeOut(duration: 0.2)) { image = loaded }
            }
            imageURL = url
            didFail = loaded == nil
        }
    }
}
