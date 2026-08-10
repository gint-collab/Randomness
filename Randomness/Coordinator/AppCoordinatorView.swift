//
//  AppCoordinatorView.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI

struct AppCoordinatorView: View {
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Group {
                if coordinator.isAuthenticated {
                    DashboardView(
                        viewModel: DashboardViewModel(
                            onSelect: { coordinator.push($0) },
                            onLogout: { coordinator.didLogout() }
                        )
                    )
                } else {
                    LandingView(
                        viewModel: LandingViewModel(onLoginSuccess: { coordinator.didLogin() })
                    )
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                coordinator.view(for: route)
            }
            .animation(.easeInOut, value: coordinator.isAuthenticated)
        }
        .environmentObject(coordinator)
    }
}

#Preview {
    AppCoordinatorView()
}
