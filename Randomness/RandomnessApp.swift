//
//  RandomnessApp.swift
//  Randomness
//
//  Created by Septuagint Murito on 8/9/26.
//

import SwiftUI
import SwiftData

@main
struct RandomnessApp: App {
    private let dependencies: AppDependenciesProtocol = AppDependencies()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView()
                .environment(\.dependencies, dependencies)
        }
        .modelContainer(sharedModelContainer)
    }
}
