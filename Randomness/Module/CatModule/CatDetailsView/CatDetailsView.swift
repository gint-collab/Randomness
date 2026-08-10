//
//  CatDetailsView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

struct CatDetailsView<ViewModel: CatDetailsViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel

    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    private var image: CatImage { viewModel.image }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                factSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
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
                placeholder(systemImage: nil)
            }
        }
        .aspectRatio(image.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                ProgressView()
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
