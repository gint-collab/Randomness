//
//  Hero.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/12/26.
//

import SwiftUI

/// Reusable hero image: a large, rounded, ratio-aware remote image with
/// shimmer and failure placeholders.
///
/// ```swift
/// Hero(url: image.url, aspectRatio: image.aspectRatio, id: image.id)
/// ```
struct Hero: View {
    private let url: String?
    private let aspectRatio: CGFloat
    /// Changing this animates the swap between images.
    private let id: AnyHashable?
    private let cornerRadius: CGFloat
    private let contentMode: ContentMode
    private let background: Color

    init(
        url: String?,
        aspectRatio: CGFloat = 1,
        id: AnyHashable? = nil,
        cornerRadius: CGFloat = 20,
        contentMode: ContentMode = .fit,
        background: Color = .gray.opacity(0.12)
    ) {
        self.url = url
        self.aspectRatio = max(aspectRatio, 0.01)
        self.id = id
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
        self.background = background
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        RemoteImage(url: url) { phase in
            switch phase {
            case .success(let loaded):
                loaded
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder
            case .empty:
                ShimmerBlock(cornerRadius: cornerRadius)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(background)
        .clipShape(shape)
        .contentShape(shape)
        .animation(.easeInOut(duration: 0.2), value: id)
    }

    private var placeholder: some View {
        ZStack {
            Color.clear
            Image(systemName: "photo.badge.exclamationmark")
                .imageScale(.large)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    Hero(
        url: "https://cdn2.thecatapi.com/images/a05.jpg",
        aspectRatio: 1,
        id: "a05"
    )
    .padding(16)
}
