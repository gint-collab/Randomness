//
//  CatListView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

struct CatListView<ViewModel: CatListViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel

    private let columnCount: Int
    private let spacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    /// Images with an intrinsic width above this take a full row on their own.
    private let wideThreshold: CGFloat = 640

    init(viewModel: @autoclosure @escaping () -> ViewModel, columnCount: Int = 2) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.columnCount = max(1, columnCount)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(1, proxy.size.width - (horizontalPadding * 2))
            let itemWidth = itemWidth(for: proxy.size.width)
            let layoutSections = sections(for: viewModel.images)

            ScrollView {
                LazyVStack(spacing: spacing) {
                    ForEach(layoutSections) { section in
                        switch section.kind {
                        case .wide(let image):
                            // Intrinsic width above the threshold: the image
                            // gets the whole row as a single column.
                            cell(for: image, width: contentWidth)
                        case .masonry(let images):
                            masonry(images, itemWidth: itemWidth)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, spacing)
            }
            .scrollIndicators(.hidden)
            // Content scrolls under the Liquid Glass tab bar with a soft edge.
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .refreshable {
                Task {
                    await viewModel.loadImages()
                }
            }
            .defaultBackground()
        }
        .overlay {
            if viewModel.isLoading && viewModel.images.isEmpty {
                CatListSkeleton(
                    columnCount: columnCount,
                    spacing: spacing,
                    horizontalPadding: horizontalPadding
                )
            } else if let message = viewModel.errorMessage, viewModel.images.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't load cats", systemImage: "cat")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { Task { await viewModel.loadImages() } }
                }
            }
        }
        .navigationTitle("Cats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - Layout pieces

    private func cell(for image: CatImage, width: CGFloat) -> some View {
        Button {
            viewModel.didSelect(image)
        } label: {
            CatImageCell(image: image, width: width)
        }
        .buttonStyle(.plain)
    }

    /// Waterfall block: each column is packed independently so the spacing
    /// stays constant even though cells have different heights (a `LazyVGrid`
    /// would align rows and leave gaps).
    private func masonry(_ images: [CatImage], itemWidth: CGFloat) -> some View {
        let columns = distributed(images, width: itemWidth)

        return HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                VStack(spacing: spacing) {
                    ForEach(column) { image in
                        cell(for: image, width: itemWidth)
                    }
                }
                .frame(width: itemWidth, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sectioning

    private struct Section: Identifiable {
        enum Kind {
            case wide(CatImage)
            case masonry([CatImage])
        }

        let id: String
        let kind: Kind
    }

    /// Splits the feed so an image with an intrinsic width above
    /// ``wideThreshold`` (640 px) takes a full-width row on its own, while the
    /// rest keep flowing through the multi-column waterfall.
    private func sections(for images: [CatImage]) -> [Section] {
        var result: [Section] = []
        var bucket: [CatImage] = []

        func flush() {
            guard let first = bucket.first else { return }
            result.append(Section(id: "masonry-\(first.id)", kind: .masonry(bucket)))
            bucket.removeAll()
        }

        for image in images {
            if CGFloat(image.width) > wideThreshold {
                flush()
                result.append(Section(id: "wide-\(image.id)", kind: .wide(image)))
            } else {
                bucket.append(image)
            }
        }
        flush()

        return result
    }

    private func itemWidth(for totalWidth: CGFloat) -> CGFloat {
        let available = totalWidth
            - (horizontalPadding * 2)
            - (spacing * CGFloat(columnCount - 1))
        return max(1, available / CGFloat(columnCount))
    }

    /// Greedy waterfall distribution: every image goes to the column that is
    /// currently the shortest, which keeps the gaps between cells constant.
    private func distributed(_ images: [CatImage], width: CGFloat) -> [[CatImage]] {
        var columns: [[CatImage]] = Array(repeating: [], count: columnCount)
        var heights = [CGFloat](repeating: 0, count: columnCount)

        for image in images {
            let shortest = heights.enumerated().min { lhs, rhs in
                lhs.element == rhs.element ? lhs.offset < rhs.offset : lhs.element < rhs.element
            }?.offset ?? 0

            columns[shortest].append(image)
            heights[shortest] += (width / max(image.aspectRatio, 0.01)) + spacing
        }

        return columns
    }
}

/// Placeholder grid shown while the first page of cats is loading.
private struct CatListSkeleton: View {
    let columnCount: Int
    let spacing: CGFloat
    let horizontalPadding: CGFloat

    private let heights: [CGFloat] = [160, 220, 190, 140, 210, 170]

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: spacing),
                    count: columnCount
                ),
                spacing: spacing
            ) {
                ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                    ShimmerBlock(cornerRadius: 12)
                        .frame(height: height)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, spacing)
        }
        .scrollDisabled(true)
        .accessibilityLabel("Loading cats")
    }
}

/// Renders a single image using the intrinsic size reported by the API,
/// so each cell keeps the original aspect ratio.
private struct CatImageCell: View {
    let image: CatImage
    let width: CGFloat

    private var height: CGFloat { width / image.aspectRatio }

    var body: some View {
        RemoteImage(url: image.url) { phase in
            switch phase {
            case .success(let loaded):
                loaded
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "photo")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            case .empty:
                ShimmerBlock(cornerRadius: 12)
            }
        }
        .frame(width: width, height: height)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Text("\(image.width)×\(image.height)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(6)
        }
        .accessibilityLabel("Cat image \(image.id), \(image.width) by \(image.height)")
    }
}

#Preview {
    NavigationStack {
        CatListView(viewModel: CatListViewModel(service: MockCatService()))
    }
}
