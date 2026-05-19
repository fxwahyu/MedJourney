//
//  JournalEntryRepository.swift
//  MedJourney
//
//  Persistence Layer — Concrete repository for JournalEntry
//

import Foundation
import SwiftData

/// Concrete repository for managing `JournalEntry` persistence via SwiftData.
///
/// Provides domain-specific query methods beyond basic CRUD,
/// such as filtering by entry type and date range.
///
/// Usage:
/// ```swift
/// let repo = JournalEntryRepository(modelContext: context)
/// let symptoms = try repo.fetchByType(.symptom)
/// ```
final class JournalEntryRepository: PersistenceRepositoryProtocol {

    typealias Model = JournalEntry

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - PersistenceRepositoryProtocol

    func fetch(
        predicate: Predicate<JournalEntry>?,
        sortBy: [SortDescriptor<JournalEntry>]
    ) throws -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: predicate,
            sortBy: sortBy
        )
        return try modelContext.fetch(descriptor)
    }

    func add(_ model: JournalEntry) throws {
        modelContext.insert(model)
        try save()
    }

    func delete(_ model: JournalEntry) throws {
        modelContext.delete(model)
        try save()
    }

    func save() throws {
        try modelContext.save()
    }

    // MARK: - Domain-Specific Queries

    /// Fetches entries of a specific type, sorted by most recent first.
    ///
    /// - Parameter type: The entry type to filter by.
    /// - Returns: Filtered and sorted entries.
    func fetchByType(_ type: JournalEntry.EntryType) throws -> [JournalEntry] {
        let typeRaw = type.rawValue
        let predicate = #Predicate<JournalEntry> { entry in
            entry.entryTypeRaw == typeRaw
        }
        return try fetch(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Fetches entries within a date range, sorted by most recent first.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range (inclusive).
    ///   - endDate: The end of the date range (inclusive).
    /// - Returns: Entries within the specified range.
    func fetchByDateRange(
        from startDate: Date,
        to endDate: Date
    ) throws -> [JournalEntry] {
        let predicate = #Predicate<JournalEntry> { entry in
            entry.createdAt >= startDate && entry.createdAt <= endDate
        }
        return try fetch(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Fetches all entries sorted by most recent first.
    ///
    /// - Returns: All entries in reverse chronological order.
    func fetchRecent() throws -> [JournalEntry] {
        try fetch(
            predicate: nil,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }
}
