//
//  SwiftDataContainer.swift
//  MedJourney
//
//  Persistence Layer — ModelContainer factory
//

import Foundation
import SwiftData

/// Factory for creating and configuring the SwiftData `ModelContainer`.
///
/// This is the single source of truth for schema registration.
/// All `@Model` types must be registered here.
///
/// Usage:
/// ```swift
/// // Production:
/// let container = SwiftDataContainer.create()
///
/// // Previews / Tests:
/// let container = SwiftDataContainer.create(inMemory: true)
/// ```
enum SwiftDataContainer {

    /// All SwiftData model types registered in the app.
    ///
    /// Add new `@Model` types here as the app grows.
    static let modelTypes: [any PersistentModel.Type] = [
        JournalEntry.self,
    ]

    /// Creates a configured `ModelContainer` with all registered models.
    ///
    /// - Parameter inMemory: If `true`, data is stored in memory only
    ///   (useful for previews and unit tests). Defaults to `false`.
    /// - Returns: A configured `ModelContainer`.
    /// - Note: Fatally crashes if the container cannot be created,
    ///   since the app cannot function without persistence.
    static func create(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(modelTypes)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError(
                "SwiftDataContainer: Failed to create ModelContainer — \(error.localizedDescription)"
            )
        }
    }
}
