//
//  JournalListView.swift
//  MedJourney
//
//  Created by user on 19/05/26.
//

import SwiftUI
import SwiftData

struct JournalTabView: View {
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var showingAddEntry: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        GradientHeader(height: 200) {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Spacer()
                                Text("Your Health Journey ✦")
                                    .styled(.labelCaps)
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("Your Entries")
                                    .appFont(.h1)
                                    .foregroundStyle(.white)
                                Text("\(entries.count) entries recorded")
                                    .appFont(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, AppSpacing.xxl)
                        }

                        VStack(spacing: AppSpacing.md) {
                            if entries.isEmpty {
                                LoadingStateView(state: .empty(
                                    title: "No entries yet",
                                    message: "Tap + to create your first health journal entry.",
                                    icon: "heart.text.square"
                                ))
                                .frame(minHeight: 300)
                            } else {
                                ForEach(entries) { entry in
                                    JournalCardView(entry: entry)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.lg)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .bottom) {
                // FAB
                Button {
                    showingAddEntry = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.brand)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        .appShadow(.fab)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.bottom, 150)
            }
            .sheet(isPresented: $showingAddEntry) {
                JournalEntryView()
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    JournalTabView()
}
