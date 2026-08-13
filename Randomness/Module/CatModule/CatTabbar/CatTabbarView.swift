//
//  CatTabbarView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI

/// Tabs hosted by ``CatTabbarView``.
enum CatTab: String, CaseIterable, Identifiable, Hashable {
    case grid
    case feed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: return "Gallery"
        case .feed: return "Feed"
        }
    }

    var systemImage: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .feed: return "list.bullet.rectangle.portrait"
        }
    }
}

/// Container that shows the cat gallery and the cat feed inside the native
/// Liquid Glass tab bar.
struct CatTabbarView: View {
    private let service: CatServiceProtocol
    /// Tapped image plus the list already loaded by the gallery.
    private let onSelectImage: (CatImage, [CatImage]) -> Void

    @State private var selection: CatTab

    init(
        service: CatServiceProtocol,
        initialTab: CatTab = .grid,
        onSelectImage: @escaping (CatImage, [CatImage]) -> Void = { _, _ in }
    ) {
        self.service = service
        self.onSelectImage = onSelectImage
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(CatTab.grid.title, systemImage: CatTab.grid.systemImage, value: .grid) {
                CatListView(
                    viewModel: CatListViewModel(
                        service: service,
                        onSelect: onSelectImage
                    )
                )
            }

            Tab(CatTab.feed.title, systemImage: CatTab.feed.systemImage, value: .feed) {
                CatFeedsView(viewModel: CatFeedsViewModel(service: service))
            }
        }
        // Native Liquid Glass behaviour on iOS 26: the bar minimizes while
        // scrolling down and expands again on scroll up. No-op on iOS 18.
        .liquidGlassTabBar()
        .tint(.pink)
        .toolbarBackground(.visible, for: .tabBar)
        .navigationTitle(selection.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Small glass accessory that rides above the tab bar, the way Music and
/// Podcasts show their now-playing bar.
///
/// The bottom tab-view accessory is an iOS 26 affordance, so this whole view is
/// gated behind that availability; on iOS 18 the tab bar simply has no accessory.
@available(iOS 26.0, *)
private struct CatTabAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let tab: CatTab

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)

            if placement != .inline {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(tab.title)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 0)

            Image(systemName: "cat.fill")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    private var subtitle: String {
        switch tab {
        case .grid: return "Browse every cat"
        case .feed: return "Latest cats and facts"
        }
    }
}

#Preview {
    NavigationStack {
        CatTabbarView(service: MockCatService())
    }
}
