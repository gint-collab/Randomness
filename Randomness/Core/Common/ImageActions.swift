//
//  ImageActions.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/13/26.
//

import SwiftUI

/// Toolbar menu offering the two standard actions for a remote image:
/// share the image itself and save it to the local photo library.
///
/// The image is pulled through `ImageDownloading`, so a picture already shown
/// on screen is served straight from cache and both actions are instant.
///
/// ```swift
/// .toolbar {
///     ToolbarItem(placement: .topBarTrailing) {
///         ImageActionsMenu(url: image.url, title: "Cat \(image.id)")
///     }
/// }
/// ```
struct ImageActionsMenu: View {
    private let urlString: String?
    /// Used as the share sheet's preview title and the accessibility label.
    private let title: String

    @Environment(\.imageDownloader) private var downloader
    @Environment(\.imageSaver) private var saver

    /// Downloaded image, so sharing sends the picture rather than a link.
    @State private var loaded: PlatformImage?
    @State private var isSaving = false
    @State private var isLoadingImage = false
    @State private var feedback: Feedback?

    init(url: String?, title: String = "Image") {
        self.urlString = url
        self.title = title
    }

    private var url: URL? { urlString.flatMap(URL.init(string:)) }

    var body: some View {
        Menu {
            shareAction
            saveAction
        } label: {
            label
        }
        .disabled(url == nil)
        .accessibilityLabel("Share or save \(title)")
        // Preload so both actions are ready by the time the menu opens.
        .task(id: urlString) { await loadImage() }
        .alert(item: $feedback) { feedback in
            Alert(
                title: Text(feedback.title),
                message: Text(feedback.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Label

    @ViewBuilder
    private var label: some View {
        if isSaving {
            ProgressView()
        } else {
            Image(systemName: "square.and.arrow.up")
        }
    }

    // MARK: - Actions

    /// Shares the decoded image when available, falling back to the URL while
    /// it is still downloading.
    @ViewBuilder
    private var shareAction: some View {
        if let loaded {
            ShareLink(
                item: Image(platformImage: loaded),
                preview: SharePreview(title, image: Image(platformImage: loaded))
            ) {
                Label("Share image", systemImage: "square.and.arrow.up")
            }
        } else if let url {
            ShareLink(item: url) {
                Label("Share link", systemImage: "link")
            }
        }
    }

    @ViewBuilder
    private var saveAction: some View {
        Button {
            Task { await save() }
        } label: {
            Label("Save to Photos", systemImage: "arrow.down.circle")
        }
        .disabled(isSaving || isLoadingImage)
    }

    // MARK: - Work

    private func loadImage() async {
        guard let url else {
            loaded = nil
            return
        }

        if let cached = downloader.cachedImage(for: url) {
            loaded = cached
            return
        }

        isLoadingImage = true
        defer { isLoadingImage = false }
        loaded = try? await downloader.image(from: url)
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        // The menu may be tapped before the preload finishes.
        if loaded == nil { await loadImage() }

        guard let image = loaded else {
            feedback = Feedback(
                title: "Couldn't save",
                message: "The image could not be downloaded. Check your connection and try again."
            )
            return
        }

        do {
            try await saver.save(image)
            feedback = Feedback(title: "Saved", message: "The image was added to your Photos.")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            feedback = Feedback(title: "Couldn't save", message: message)
        }
    }

    /// Result message shown after a save attempt.
    private struct Feedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}

#Preview {
    NavigationStack {
        Color.gray.opacity(0.2)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ImageActionsMenu(
                        url: "https://cdn2.thecatapi.com/images/a05.jpg",
                        title: "Cat a05"
                    )
                }
            }
    }
}
