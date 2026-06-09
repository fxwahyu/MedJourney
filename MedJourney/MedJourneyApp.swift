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

        // Seed demo data on first launch
        SeedDataManager.seedIfNeeded(context: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.dependencyContainer, dependencyContainer)
        }
        .modelContainer(modelContainer)
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        if hasOnboarded {
            ContentView()
        } else {
            OnboardingView()
        }
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
