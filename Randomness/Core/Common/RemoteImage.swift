//
//  RemoteImage.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

/// Loading state of a `RemoteImage`.
enum RemoteImagePhase {
    case empty
    case success(Image)
    case failure(Error)

    var image: Image? {
        if case .success(let image) = self { return image }
        return nil
    }

    var error: Error? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

/// Reusable, cache-backed replacement for `AsyncImage`.
///
/// Uses the injected `ImageDownloading` from the environment so previews and
/// tests can supply a stub, and so repeated URLs are served from cache.
struct RemoteImage<Content: View>: View {
    @Environment(\.imageDownloader) private var downloader

    private let url: URL?
    private let transaction: Transaction
    private let content: (RemoteImagePhase) -> Content

    @State private var phase: RemoteImagePhase = .empty

    init(
        url: URL?,
        transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.2)),
        @ViewBuilder content: @escaping (RemoteImagePhase) -> Content
    ) {
        self.url = url
        self.transaction = transaction
        self.content = content
    }

    init(
        url string: String?,
        transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.2)),
        @ViewBuilder content: @escaping (RemoteImagePhase) -> Content
    ) {
        self.init(
            url: string.flatMap(URL.init(string:)),
            transaction: transaction,
            content: content
        )
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }

        if let cached = downloader.cachedImage(for: url) {
            phase = .success(Image(platformImage: cached))
            return
        }

        phase = .empty
        do {
            let image = try await downloader.image(from: url)
            guard !Task.isCancelled else { return }
            withTransaction(transaction) {
                phase = .success(Image(platformImage: image))
            }
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failure(error)
        }
    }
}

// MARK: - Convenience

extension RemoteImage where Content == AnyView {
    /// Simple variant: resizable image with a placeholder and a failure symbol.
    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        placeholder: @escaping () -> AnyView = { AnyView(ProgressView()) },
        failure: @escaping () -> AnyView = {
            AnyView(
                Image(systemName: "photo")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            )
        }
    ) {
        // Built outside the `@ViewBuilder` closure so the result is a single
        // `AnyView` rather than a `_ConditionalContent` tree.
        let build: (RemoteImagePhase) -> AnyView = { phase in
            switch phase {
            case .success(let image):
                return AnyView(image.resizable().aspectRatio(contentMode: contentMode))
            case .failure:
                return failure()
            case .empty:
                return placeholder()
            }
        }

        self.init(url: url) { phase in
            build(phase)
        }
    }
}

#Preview {
    RemoteImage(url: URL(string: "https://api.chucknorris.io/img/avatar/chuck-norris.png")) { phase in
        switch phase {
        case .success(let image):
            image.resizable().scaledToFit()
        case .failure:
            Image(systemName: "exclamationmark.triangle")
        case .empty:
            ProgressView()
        }
    }
    .frame(width: 120, height: 120)
}
