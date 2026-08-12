//
//  Shimmer.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/11/26.
//

import SwiftUI

// MARK: - Configuration

/// Tweakable look & feel of the shimmer effect.
struct ShimmerConfiguration: Equatable, Sendable {
    /// Base colour of the skeleton shapes.
    var base: Color
    /// Colour of the travelling highlight.
    var highlight: Color
    /// How wide the highlight band is, relative to the view width (0...1).
    var bandWidth: CGFloat
    /// Angle of the travelling band.
    var angle: Angle
    /// One full sweep duration, in seconds.
    var duration: Double
    /// Pause between sweeps, in seconds.
    var delay: Double
    /// Blend mode used by the highlight band.
    var blendMode: BlendMode

    /// Instagram-style skeleton: flat grey placeholders with a soft, wide and
    /// slightly tilted light band sweeping across them.
    static let instagram = ShimmerConfiguration(
        base: Color(.systemGray5),
        highlight: Color(.systemGray6).opacity(0.95),
        bandWidth: 0.55,
        angle: .degrees(20),
        duration: 1.3,
        delay: 0.1,
        blendMode: .normal
    )

    /// Default look used everywhere unless overridden.
    static let `default` = ShimmerConfiguration.instagram

    /// Softer variant for use on top of already tinted / glass surfaces.
    static let subtle = ShimmerConfiguration(
        base: Color(.systemGray5).opacity(0.6),
        highlight: Color(.systemGray6).opacity(0.6),
        bandWidth: 0.6,
        angle: .degrees(20),
        duration: 1.6,
        delay: 0.2,
        blendMode: .normal
    )

    /// Medium-dark variant for large hero areas or photo backdrops.
    static let dark = ShimmerConfiguration(
        base: Color.black.opacity(0.35),
        highlight: Color.white.opacity(0.3),
        bandWidth: 0.35,
        angle: .degrees(20),
        duration: 1.2,
        delay: 0.15,
        blendMode: .plusLighter
    )
}

// MARK: - Modifier

/// Sweeps a soft highlight across any view, masked by the view itself, so it
/// works for text, shapes, images and whole layouts alike.
private struct ShimmerModifier: ViewModifier {
    let configuration: ShimmerConfiguration
    let isActive: Bool

    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay {
                    if !reduceMotion {
                        GeometryReader { proxy in
                            let width = max(proxy.size.width, 1)
                            let band = max(width * configuration.bandWidth, 1)

                            // Soft-edged band, like Instagram's placeholder sweep.
                            LinearGradient(
                                stops: [
                                    .init(color: configuration.highlight.opacity(0), location: 0),
                                    .init(color: configuration.highlight, location: 0.5),
                                    .init(color: configuration.highlight.opacity(0), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: band)
                            .rotationEffect(configuration.angle)
                            .scaleEffect(y: 1.6)
                            .offset(x: phase * (width + band))
                            .frame(width: width, alignment: .leading)
                        }
                        .blendMode(configuration.blendMode)
                        .allowsHitTesting(false)
                    }
                }
                .mask(content)
                .onAppear { startAnimating() }
                // `repeatForever` never ends on its own, so it keeps ticking
                // (and keeps the view's storage alive) after the skeleton is
                // scrolled away. Explicitly stop it when the view goes away.
                .onDisappear { stopAnimating() }
        } else {
            content
        }
    }

    private func startAnimating() {
        guard isActive, !reduceMotion else { return }
        phase = -1
        withAnimation(
            .linear(duration: configuration.duration)
            .delay(configuration.delay)
            .repeatForever(autoreverses: false)
        ) {
            phase = 1
        }
    }

    private func stopAnimating() {
        withAnimation(.linear(duration: 0)) { phase = -1 }
    }
}

// MARK: - View API

extension View {
    /// Adds a shimmering highlight to the receiver.
    ///
    /// ```swift
    /// Text("Loading")
    ///     .shimmering()
    ///
    /// CardView()
    ///     .shimmering(isActive: viewModel.isLoading, configuration: .subtle)
    /// ```
    func shimmering(
        isActive: Bool = true,
        configuration: ShimmerConfiguration = .default
    ) -> some View {
        modifier(ShimmerModifier(configuration: configuration, isActive: isActive))
    }

    /// Replaces the receiver with a shimmering skeleton while `isLoading`.
    ///
    /// Useful when the real layout is already known: the content is redacted
    /// so the placeholder automatically matches its size.
    @ViewBuilder
    func skeleton(
        _ isLoading: Bool,
        configuration: ShimmerConfiguration = .default
    ) -> some View {
        if isLoading {
            self
                .redacted(reason: .placeholder)
                .shimmering(configuration: configuration)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            self
        }
    }
}

// MARK: - Ready-made skeleton shapes

/// A shimmering block that can stand in for any content: images, rows, avatars…
struct ShimmerBlock<S: Shape>: View {
    private let shape: S
    private let configuration: ShimmerConfiguration

    init(shape: S, configuration: ShimmerConfiguration = .default) {
        self.shape = shape
        self.configuration = configuration
    }

    var body: some View {
        shape
            .fill(configuration.base)
            .shimmering(configuration: configuration)
            .accessibilityHidden(true)
    }
}

extension ShimmerBlock where S == RoundedRectangle {
    /// Rounded rectangle skeleton, the most common case.
    init(cornerRadius: CGFloat = 12, configuration: ShimmerConfiguration = .default) {
        self.init(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            configuration: configuration
        )
    }
}

extension ShimmerBlock where S == Circle {
    /// Circular skeleton, e.g. for avatars.
    static func circle(configuration: ShimmerConfiguration = .default) -> ShimmerBlock<Circle> {
        ShimmerBlock<Circle>(shape: Circle(), configuration: configuration)
    }
}

/// A few shimmering lines standing in for a paragraph of text.
struct ShimmerText: View {
    var lines: Int = 3
    var lineHeight: CGFloat = 12
    var spacing: CGFloat = 8
    /// Width factor of the last line, so the block doesn't look like a wall.
    var lastLineWidth: CGFloat = 0.6
    var configuration: ShimmerConfiguration = .default

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<max(lines, 1), id: \.self) { index in
                ShimmerBlock(cornerRadius: lineHeight / 2, configuration: configuration)
                    .frame(height: lineHeight)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .scaleEffect(
                        x: index == lines - 1 ? lastLineWidth : 1,
                        anchor: .leading
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Shimmer") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            ShimmerBlock(cornerRadius: 16)
                .frame(height: 180)

            HStack(spacing: 12) {
                ShimmerBlock.circle()
                    .frame(width: 44, height: 44)
                ShimmerText(lines: 2)
            }

            ShimmerText(lines: 4)

            Label("Redacted skeleton", systemImage: "cat")
                .font(.headline)
                .skeleton(true)
        }
        .padding()
    }
}
