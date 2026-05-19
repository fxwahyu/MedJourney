//
//  PersistenceRepositoryProtocol.swift
//  MedJourney
//
//  Persistence Layer — Generic repository abstraction
//

import Foundation
import SwiftData

/// Defines a generic CRUD contract for SwiftData persistence.
///
/// This protocol abstracts SwiftData internals so that ViewModels
/// never depend on `ModelContext` directly. Repositories conforming
/// to this protocol can be easily mocked for testing.
///
/// - Note: The `Model` associated type must conform to `PersistentModel`.
protocol PersistenceRepositoryProtocol {

    /// The SwiftData model type this repository manages.
    associatedtype Model: PersistentModel

    /// Fetches all instances, optionally filtered and sorted.
    ///
    /// - Parameters:
    ///   - predicate: Optional filter predicate.
    ///   - sortBy: Sort descriptors for ordering results.
    /// - Returns: An array of matching model instances.
    func fetch(
        predicate: Predicate<Model>?,
        sortBy: [SortDescriptor<Model>]
    ) throws -> [Model]

    /// Inserts a new model instance into the persistent store.
    ///
    /// - Parameter model: The model instance to insert.
    func add(_ model: Model) throws

    /// Deletes a model instance from the persistent store.
    ///
    /// - Parameter model: The model instance to delete.
    func delete(_ model: Model) throws

    /// Saves any pending changes to the persistent store.
    func save() throws
}

// MARK: - Default Parameter Values

extension PersistenceRepositoryProtocol {

    /// Convenience: fetch all with no filter and default sort.
    func fetchAll() throws -> [Model] {
        try fetch(predicate: nil, sortBy: [])
    }
}
