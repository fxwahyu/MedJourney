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

    init() {
        // Initialize SwiftData container
        modelContainer = SwiftDataContainer.create()

        // Seed demo data on first launch
        SeedDataManager.seedIfNeeded(context: modelContainer.mainContext)
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
            ContentView()
        } else {
            OnboardingView()
        }
    }
}
