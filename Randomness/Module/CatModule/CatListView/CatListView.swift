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

    init(viewModel: @autoclosure @escaping () -> ViewModel, columnCount: Int = 2) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.columnCount = max(1, columnCount)
    }

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = itemWidth(for: proxy.size.width)

            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(itemWidth), spacing: spacing),
                        count: columnCount
                    ),
                    spacing: spacing
                ) {
                    ForEach(viewModel.images) { image in
                        Button {
                            viewModel.didSelect(image)
                        } label: {
                            CatImageCell(image: image, width: itemWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, spacing)
            }
            .scrollIndicators(.hidden)
            // Content scrolls under the Liquid Glass tab bar with a soft edge.
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .refreshable { await viewModel.loadImages() }
        }
        .overlay {
            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView()
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

    private func itemWidth(for totalWidth: CGFloat) -> CGFloat {
        let available = totalWidth
            - (horizontalPadding * 2)
            - (spacing * CGFloat(columnCount - 1))
        return max(1, available / CGFloat(columnCount))
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
                ProgressView()
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
