//
//  Carousel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/12/26.
//

import SwiftUI

/// Visual configuration for `Carousel`.
struct CarouselStyle {
    var spacing: CGFloat = 16
    var cornerRadius: CGFloat = 24
    var minHeight: CGFloat = 220
    var maxHeight: CGFloat = 520
    /// Height used when no `aspectRatio` is provided.
    var fixedHeight: CGFloat = 320
    var inactiveOpacity: CGFloat = 0.6
    var inactiveScale: CGFloat = 0.9
    var tiltDegrees: Double = 8
    var showsPageIndicator: Bool = true
    var background: Color = .gray.opacity(0.12)
    var borderColor: Color = .primary.opacity(0.06)
    var shadowRadius: CGFloat = 24

    static var `default`: CarouselStyle { CarouselStyle() }
}

/// A modern, reusable paging carousel.
///
/// - View-aligned paging with a two-way `selection` binding.
/// - Interactive scroll transitions (fade, scale and a subtle 3D tilt).
/// - Optional height that follows the selected item's aspect ratio.
/// - Optional capsule page indicator.
///
/// ```swift
/// Carousel(items: images, selection: $selectedID, aspectRatio: { $0.aspectRatio }) { image in
///     RemoteImage(url: image.url) { _ in EmptyView() }
/// }
/// ```
struct Carousel<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    @Binding private var selection: Item.ID?
    private let aspectRatio: ((Item) -> CGFloat)?
    private let style: CarouselStyle
    private let content: (Item) -> Content

    @State private var measuredWidth: CGFloat = 0

    init(
        items: [Item],
        selection: Binding<Item.ID?>,
        aspectRatio: ((Item) -> CGFloat)? = nil,
        style: CarouselStyle = .default,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self._selection = selection
        self.aspectRatio = aspectRatio
        self.style = style
        self.content = content
    }

    // MARK: - Layout

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
    }

    private var selectedItem: Item? {
        items.first { $0.id == selection } ?? items.first
    }

    /// Height driven by the selected item's ratio, clamped to sane bounds.
    private var height: CGFloat {
        guard let aspectRatio, let selectedItem, measuredWidth > 0 else {
            return style.fixedHeight
        }
        let ratio = max(aspectRatio(selectedItem), 0.01)
        return min(max(measuredWidth / ratio, style.minHeight), style.maxHeight)
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: style.spacing) {
                    ForEach(items) { item in
                        card(for: item)
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                                view
                                    .opacity(phase.isIdentity ? 1 : style.inactiveOpacity)
                                    .scaleEffect(phase.isIdentity ? 1 : style.inactiveScale)
                                    .rotation3DEffect(
                                        .degrees(phase.value * -style.tiltDegrees),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.5
                                    )
                            }
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selection, anchor: .center)
            .frame(height: height)
            .animation(.snappy, value: height)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { measuredWidth = $0 }
            .onAppear {
                if selection == nil { selection = items.first?.id }
            }

            if style.showsPageIndicator && items.count > 1 {
                pageIndicator
            }
        }
    }

    private func card(for item: Item) -> some View {
        content(item)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(style.background)
            .clipShape(shape)
            .contentShape(shape)
            .overlay {
                shape.strokeBorder(style.borderColor, lineWidth: 1)
            }
            // Flatten the clipped card before the scroll transition applies its
            // 3D transform, otherwise the rounded corners render squared off.
            .compositingGroup()
            .shadow(color: .black.opacity(0.15), radius: style.shadowRadius, y: 6)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                let isSelected = item.id == selectedItem?.id
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: isSelected ? 18 : 6, height: 6)
                    .animation(.snappy, value: isSelected)
                    .onTapGesture {
                        withAnimation(.snappy) { selection = item.id }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

#Preview {
    struct Demo: View {
        struct Item: Identifiable { let id: Int; let color: Color; let ratio: CGFloat }

        @State private var selection: Int?

        private let items = [
            Item(id: 0, color: .pink, ratio: 1.6),
            Item(id: 1, color: .teal, ratio: 0.8),
            Item(id: 2, color: .orange, ratio: 1.0)
        ]

        var body: some View {
            Carousel(items: items, selection: $selection, aspectRatio: { $0.ratio }) { item in
                item.color
            }
            .padding(.horizontal, 16)
        }
    }

    return Demo()
}
