//
//  MainTabView.swift
//  MedJourney
//

import SwiftUI
import SwiftData

/// The five-tab root of the app. The center "+" tab is a fake tab that opens
/// the add-content sheet instead of switching views.
struct MainTabView: View {

    @State private var selectedTab = 0
    @State private var showAddContent = false
    @State private var showMoodSheet = false
    @State private var showCheckupSheet = false
    @State private var showMedicineSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {

                HomeTabView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                JournalTabView()
                    .tabItem { Label("Journal", systemImage: "heart.text.square") }
                    .tag(1)

                Color.clear
                    .tabItem { Label("Add", systemImage: "plus") }
                    .tag(2)

                MedicineTabView()
                    .tabItem { Label("Medicine", systemImage: "pills.fill") }
                    .tag(3)

                InsightsTabView()
                    .tabItem { Label("Insights", systemImage: "sparkles") }
                    .tag(4)
            }
            .tint(AppColors.brandDark)
            .onChange(of: selectedTab) { _, tab in
                if tab == 2 {
                    showAddContent = true
                    selectedTab = 0
                }
            }

            centerAddButton
        }
        .sheet(isPresented: $showAddContent) {
            AddContentSheet(
                showMoodSheet: $showMoodSheet,
                showCheckupSheet: $showCheckupSheet,
                showMedicineSheet: $showMedicineSheet
            )
        }
        .sheet(isPresented: $showMoodSheet) {
            JournalMoodSheet()
        }
        .sheet(isPresented: $showCheckupSheet) {
            CheckupUploadView()
        }
        .sheet(isPresented: $showMedicineSheet) {
            AddMedicineView()
        }
    }

    // MARK: - Center Add Button

    private var centerAddButton: some View {
        GeometryReader { geo in
            Button {
                showAddContent = true
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.brand.opacity(0.22))
                        .frame(width: 76, height: 76)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.brand, AppColors.brandDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)
                        .shadow(color: AppColors.brand.opacity(0.34), radius: 24, x: 0, y: 10)

                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .position(x: geo.size.width / 2, y: geo.size.height - 28)
        }
        .frame(height: 0)
        .allowsHitTesting(true)
    }
}

#Preview {
    MainTabView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
