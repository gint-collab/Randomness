//
//  CatFeedsView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

/// Facebook-style vertical feed of cat posts.
struct CatFeedsView<ViewModel: CatFeedsViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel

    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.posts) { post in
                    CatPostCard(
                        post: post,
                        onLike: { viewModel.toggleLike(post) }
                    )
                    .task { await viewModel.loadMoreIfNeeded(currentItem: post) }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 24)
                }
            }
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
        .scrollIndicators(.hidden)
        // Lets content scroll under the Liquid Glass tab bar while staying legible.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .refreshable { await viewModel.refresh() }
        .overlay {
            if viewModel.posts.isEmpty {
                if let message = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't load feed", systemImage: "cat")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry") { Task { await viewModel.refresh() } }
                    }
                } else if viewModel.isLoading || viewModel.isLoadingMore {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Cat Feed")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Post card

private struct CatPostCard: View {
    let post: CatPost
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let fact = post.fact {
                Text(fact.fact)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
            media
            counters
            Divider().padding(.horizontal, 12)
            actionBar
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 8)
    }

    private var header: some View {
        HStack(spacing: 10) {
            RemoteImage(url: post.image.url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorName)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text(post.postedAt, format: .relative(presentation: .named))
                    Text("·")
                    Image(systemName: "globe.americas.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                ShareLink(item: URL(string: post.image.url) ?? URL(fileURLWithPath: "/")) {
                    Label("Share image", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .padding(.horizontal, 12)
    }

    private var media: some View {
        RemoteImage(url: post.image.url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder(systemImage: "photo.badge.exclamationmark")
            case .empty:
                placeholder(systemImage: nil)
            }
        }
        .aspectRatio(post.image.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(Color.gray.opacity(0.12))
        .accessibilityLabel("Cat image \(post.image.id)")
    }

    private var counters: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(4)
                .background(Color.pink, in: Circle())
            Text("\(post.likeCount)")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var actionBar: some View {
        HStack {
            actionButton(
                title: "Like",
                systemImage: post.isLiked ? "heart.fill" : "heart",
                tint: post.isLiked ? Color.pink : .secondary,
                action: onLike
            )
            ShareLink(item: URL(string: post.image.url) ?? URL(fileURLWithPath: "/")) {
                Label("Share", systemImage: "arrowshape.turn.up.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
        CatFeedsView(
            viewModel: CatFeedsViewModel(
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
