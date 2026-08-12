//
//  CatDetailsView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

/// Single-cat detail screen: hero image, related thumbnails and a cat fact.
struct CatDetailsView<ViewModel: CatDetailsViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel

    /// Extra bottom inset so a floating tab bar never covers content.
    private let bottomInset: CGFloat

    init(viewModel: @autoclosure @escaping () -> ViewModel, bottomInset: CGFloat = 0) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.bottomInset = bottomInset
    }

    private var image: CatImage { viewModel.image }

    /// Drives the paging carousel; kept in sync with the view model selection.
    @State private var carouselID: String?

    /// Images shown in the carousel (falls back to the single hero image).
    private var carouselImages: [CatImage] {
        viewModel.relatedImages.isEmpty ? [image] : viewModel.relatedImages
    }

    /// Measured width of the carousel so card height can follow the image ratio.
    private let minCardHeight: CGFloat = 220
    private let maxCardHeight: CGFloat = 520

    /// Single source of truth for every rounded corner on this screen.
    private let cornerRadius: CGFloat = 24

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                carousel
                factSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24 + bottomInset)
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.loadFact() }
        .navigationTitle("Cat Fact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: URL(string: image.url) ?? URL(fileURLWithPath: "/")) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(URL(string: image.url) == nil)
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.cancelPendingWork() }
    }

    // MARK: - Sections

    /// Full-bleed paging carousel that replaces the old hero + thumbnail strip.
    @ViewBuilder
    private var carousel: some View {
        if viewModel.isLoadingRelated && viewModel.relatedImages.isEmpty {
            ShimmerBlock(cornerRadius: cornerRadius)
                .frame(maxWidth: .infinity)
                .frame(height: 320)
        } else {
            Carousel(
                items: carouselImages,
                selection: $carouselID,
                aspectRatio: { $0.aspectRatio },
                style: carouselStyle
            ) { item in
                Hero(
                    url: item.url,
                    aspectRatio: item.aspectRatio,
                    id: item.id,
                    cornerRadius: 0,
                    contentMode: .fill,
                    background: .clear
                )
                .accessibilityLabel("Cat image \(item.id)")
                .accessibilityAddTraits(item.id == image.id ? .isSelected : [])
            }
            .onAppear { carouselID = image.id }
            .onChange(of: carouselID) { _, newValue in
                guard
                    let newValue,
                    let selected = carouselImages.first(where: { $0.id == newValue })
                else { return }
                viewModel.select(selected)
            }
            .onChange(of: image.id) { _, newValue in
                guard carouselID != newValue else { return }
                withAnimation(.snappy) { carouselID = newValue }
            }
        }
    }

    private var carouselStyle: CarouselStyle {
        var style = CarouselStyle.default
        style.cornerRadius = cornerRadius
        style.minHeight = minCardHeight
        style.maxHeight = maxCardHeight
        return style
    }

    @ViewBuilder
    private var factSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cat fact", systemImage: "lightbulb")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.loadFact() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
            }

            if let fact = viewModel.fact {
                Text(fact.fact)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .clipShape(cardShape)
    }
}

#Preview {
    NavigationStack {
        CatDetailsView(
            viewModel: CatDetailsViewModel(
                image: CatImage(
                    id: "a05",
                    url: "https://cdn2.thecatapi.com/images/a05.jpg",
                    width: 640,
                    height: 640
                ),
                service: MockCatService()
            )
        )
    }
}
