//
//  ImageDownloader.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

// MARK: - Protocol

/// Downloads (and caches) remote images.
protocol ImageDownloading: Sendable {
    func image(from url: URL) async throws -> PlatformImage
    func cachedImage(for url: URL) -> PlatformImage?
    func prefetch(_ urls: [URL]) async
    func clearCache()
}

extension ImageDownloading {
    func image(from string: String) async throws -> PlatformImage {
        guard let url = URL(string: string) else { throw NetworkError.invalidURL }
        return try await image(from: url)
    }
}

// MARK: - Cache

/// Thread-safe in-memory image cache backed by `NSCache`.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache: NSCache<NSURL, PlatformImage> = {
        let cache = NSCache<NSURL, PlatformImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // ~100 MB
        return cache
    }()

    init() {}

    func image(for url: URL) -> PlatformImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: PlatformImage, for url: URL, cost: Int = 0) {
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Downloader

/// `URLSession` backed image downloader with in-memory caching and
/// request coalescing (concurrent requests for the same URL share one task).
actor ImageDownloader: ImageDownloading {
    static let shared = ImageDownloader()

    private let session: URLSession
    private let cache: ImageCache
    private var inFlight: [URL: Task<PlatformImage, Error>] = [:]

    init(session: URLSession = .shared, cache: ImageCache = .shared) {
        self.session = session
        self.cache = cache
    }

    nonisolated func cachedImage(for url: URL) -> PlatformImage? {
        ImageCache.shared.image(for: url)
    }

    func image(from url: URL) async throws -> PlatformImage {
        if let cached = cache.image(for: url) { return cached }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<PlatformImage, Error> { [session, cache] in
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(from: url)
            } catch {
                throw NetworkError.underlying(error)
            }

            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw NetworkError.statusCode(http.statusCode)
            }

            guard let image = PlatformImage(data: data) else {
                throw NetworkError.invalidResponse
            }

            cache.insert(image, for: url, cost: data.count)
            return image
        }

        inFlight[url] = task

        // Clear the entry from inside the actor once the work finishes, rather
        // than in a `defer` on the *calling* task: a cancelled caller would
        // otherwise drop an entry that other callers are still awaiting, and a
        // task stored after a newer one would evict the newer entry.
        defer {
            if inFlight[url] == task { inFlight[url] = nil }
        }
        return try await task.value
    }

    func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls where cache.image(for: url) == nil {
                group.addTask { [weak self] in
                    _ = try? await self?.image(from: url)
                }
            }
        }
    }

    nonisolated func clearCache() {
        ImageCache.shared.removeAll()
    }
}

// MARK: - Preview / test double

struct MockImageDownloader: ImageDownloading {
    var stub: PlatformImage?
    var error: Error?

    func image(from url: URL) async throws -> PlatformImage {
        if let error { throw error }
        guard let stub else { throw NetworkError.invalidResponse }
        return stub
    }

    func cachedImage(for url: URL) -> PlatformImage? { stub }
    func prefetch(_ urls: [URL]) async {}
    func clearCache() {}
}

// MARK: - Environment

private struct ImageDownloaderKey: EnvironmentKey {
    static let defaultValue: ImageDownloading = ImageDownloader.shared
}

extension EnvironmentValues {
    var imageDownloader: ImageDownloading {
        get { self[ImageDownloaderKey.self] }
        set { self[ImageDownloaderKey.self] = newValue }
    }
}

// MARK: - Image helper

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}
