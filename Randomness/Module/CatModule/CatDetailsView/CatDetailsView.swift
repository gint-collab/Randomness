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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                relatedStrip
                factSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24 + bottomInset)
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.loadFact() }
        .navigationTitle("Cat")
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
    }

    // MARK: - Sections

    private var hero: some View {
        RemoteImage(url: image.url) { phase in
            switch phase {
            case .success(let loaded):
                loaded
                    .resizable()
                    .scaledToFit()
            case .failure:
                placeholder(systemImage: "photo.badge.exclamationmark")
            case .empty:
                ShimmerBlock(cornerRadius: 20)
            }
        }
        .aspectRatio(image.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: image.id)
    }

    @ViewBuilder
    private var relatedStrip: some View {
        if viewModel.isLoadingRelated && viewModel.relatedImages.isEmpty {
            ShimmerBlock(cornerRadius: 12)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if viewModel.relatedImages.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("More cats")
                    .font(.headline)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.relatedImages) { item in
                            Button {
                                viewModel.select(item)
                            } label: {
                                thumbnail(for: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func thumbnail(for item: CatImage) -> some View {
        let isSelected = item.id == image.id
        return RemoteImage(url: item.url) { phase in
            switch phase {
            case .success(let loaded):
                loaded.resizable().scaledToFill()
            case .failure:
                Color.gray.opacity(0.2)
            case .empty:
                ProgressView()
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .accessibilityLabel("Cat image \(item.id)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Color.clear
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            } else {
                ShimmerBlock(cornerRadius: 20)
            }
        }
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
