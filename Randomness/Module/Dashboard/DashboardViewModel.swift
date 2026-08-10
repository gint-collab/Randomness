//
//  DashboardViewModel.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/10/26.
//

import SwiftUI
import Combine

enum ListItems: String, CaseIterable, Identifiable {
    case cat = "Cats"
    case chuckNorris = "Chuck Norris"

    var id: String { rawValue }

    var route: AppRoute {
        switch self {
        case .cat: return .catList
        case .chuckNorris: return .chuckNorris
        }
    }
}

@MainActor
protocol DashboardViewModelProtocol: LoadableViewModel {
    var items: [ListItems] { get }
    func didSelect(_ item: ListItems)
    func didTapLogout()
}

@MainActor
final class DashboardViewModel: DashboardViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var items: [ListItems] = ListItems.allCases

    private let onSelect: (AppRoute) -> Void
    private let onLogout: CompletionHandler

    init(
        onSelect: @escaping (AppRoute) -> Void = { _ in },
        onLogout: @escaping CompletionHandler
    ) {
        self.onSelect = onSelect
        self.onLogout = onLogout
    }

    func didSelect(_ item: ListItems) {
        onSelect(item.route)
    }

    func didTapLogout() {
        onLogout()
    }
}
