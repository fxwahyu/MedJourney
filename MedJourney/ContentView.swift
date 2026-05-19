//
//  ContentView.swift
//  MedJourney
//
//  Created by user on 19/05/26.
//

import SwiftUI
import SwiftData

/// Root view — thin tab coordinator.
///
/// Each tab is its own standalone view:
/// - **Posts**: `PostListView` — networking + MVVM demo
/// - **Journal**: `JournalTabView` — SwiftData persistence demo
/// - **Components**: `ComponentsTabView` — design system showcase
struct ContentView: View {

    @Environment(\.dependencyContainer) private var container
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
//            PostListView(
//                viewModel: PostListViewModel(
//                    repository: container.resolve(PostRepositoryProtocol.self)
//                )
//            )
//            .tabItem {
//                Label("Posts", systemImage: "list.bullet.rectangle")
//            }
//            .tag(0)

            JournalTabView()
                .tabItem {
                    Label("Journal", systemImage: "heart.text.square")
                }
                .tag(0)

            ComponentsTabView()
                .tabItem {
                    Label("Components", systemImage: "square.grid.2x2")
                }
                .tag(1)
        }
        .tint(AppColors.brandDark)
    }
}

#Preview {
    ContentView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
