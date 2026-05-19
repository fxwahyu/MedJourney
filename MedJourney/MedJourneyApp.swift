//
//  MedJourneyApp.swift
//  MedJourney
//
//  Created by user on 19/05/26.
//

import SwiftUI
import SwiftData

@main
struct MedJourneyApp: App {

    let modelContainer: ModelContainer
    let dependencyContainer: DependencyContainer

    init() {
        // Initialize SwiftData container
        modelContainer = SwiftDataContainer.create()

        // Initialize dependency injection
        dependencyContainer = DependencyContainer.shared
        dependencyContainer.registerDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dependencyContainer, dependencyContainer)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Environment Key for DI Container

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = .shared
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
