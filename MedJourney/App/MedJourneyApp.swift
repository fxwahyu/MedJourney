//
//  MedJourneyApp.swift
//  MedJourney
//

import SwiftUI
import SwiftData

@main
struct MedJourneyApp: App {

    let modelContainer: ModelContainer

    init() {
        modelContainer = SwiftDataContainer.create()
//        SeedDataManager.seedIfNeeded(context: modelContainer.mainContext)

        // Touch the singleton at launch so its notification-center delegate is
        // registered before any reminder fires.
        _ = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        if hasOnboarded {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}
