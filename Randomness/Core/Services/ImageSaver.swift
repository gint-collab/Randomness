//
//  ImageSaver.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/13/26.
//

import SwiftUI
import Photos

// MARK: - Protocol

/// Saves an image to the user's local photo library.
protocol ImageSaving: Sendable {
    /// Writes `image` to the photo library, requesting permission if needed.
    /// - Throws: `ImageSaveError` when permission is denied or the write fails.
    func save(_ image: PlatformImage) async throws
}

/// Everything that can go wrong while saving to the photo library.
enum ImageSaveError: LocalizedError {
    /// The user denied (or restricted) add-only photo library access.
    case permissionDenied
    /// The library rejected the write.
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Randomness needs permission to add photos. Enable it in Settings › Privacy › Photos."
        case .writeFailed(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Photo library implementation

/// `PHPhotoLibrary` backed saver using add-only access, which shows the
/// lightest-weight permission prompt.
struct PhotoLibraryImageSaver: ImageSaving {
    static let shared = PhotoLibraryImageSaver()

    func save(_ image: PlatformImage) async throws {
        try await requestAddOnlyAccess()

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            throw ImageSaveError.writeFailed(error)
        }
    }

    private func requestAddOnlyAccess() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard granted == .authorized || granted == .limited else {
                throw ImageSaveError.permissionDenied
            }
        case .denied, .restricted:
            throw ImageSaveError.permissionDenied
        @unknown default:
            throw ImageSaveError.permissionDenied
        }
    }
}

// MARK: - Preview / test double

/// Records saves instead of touching the photo library.
final class MockImageSaver: ImageSaving, @unchecked Sendable {
    private(set) var savedCount = 0
    var error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func save(_ image: PlatformImage) async throws {
        if let error { throw error }
        savedCount += 1
    }
}

// MARK: - Environment

private struct ImageSaverKey: EnvironmentKey {
    static let defaultValue: ImageSaving = PhotoLibraryImageSaver.shared
}

extension EnvironmentValues {
    var imageSaver: ImageSaving {
        get { self[ImageSaverKey.self] }
        set { self[ImageSaverKey.self] = newValue }
    }
}
