//
//  DependencyContainer.swift
//  MedJourney
//
//  Core DI — Simple dependency injection container
//

import Foundation

/// A simple, protocol-based dependency injection container.
///
/// Registers and resolves dependencies for the app. All ViewModels
/// resolve their dependencies through this container, enabling
/// easy swapping for tests.
///
/// Usage:
/// ```swift
/// // Register (typically in app init):
/// let container = DependencyContainer.shared
/// container.register(NetworkServiceProtocol.self) { NetworkService() }
///
/// // Resolve:
/// let networkService: NetworkServiceProtocol = container.resolve()
/// ```
final class DependencyContainer {

    // MARK: - Singleton

    /// Shared app-wide container.
    static let shared = DependencyContainer()

    // MARK: - Storage

    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]

    private init() {}

    // MARK: - Registration

    /// Registers a factory closure for a given type.
    ///
    /// - Parameters:
    ///   - type: The protocol or type to register.
    ///   - isSingleton: If true, the factory is called once and the result cached.
    ///   - factory: A closure that creates the dependency.
    func register<T>(
        _ type: T.Type,
        isSingleton: Bool = false,
        factory: @escaping () -> T
    ) {
        let key = String(describing: type)
        if isSingleton {
            singletons[key] = factory()
        } else {
            factories[key] = factory
        }
    }

    /// Resolves a registered dependency.
    ///
    /// - Returns: An instance of the requested type.
    /// - Note: Fatal error if the type was never registered.
    func resolve<T>(_ type: T.Type = T.self) -> T {
        let key = String(describing: type)

        if let singleton = singletons[key] as? T {
            return singleton
        }

        guard let factory = factories[key], let instance = factory() as? T else {
            fatalError("DependencyContainer: No registration for \(key)")
        }

        return instance
    }

    // MARK: - Setup

    /// Registers all app-wide dependencies.
    ///
    /// Call this once during app initialization.
    func registerDependencies() {
        // Networking
        register(NetworkServiceProtocol.self, isSingleton: true) {
            NetworkService()
        }

        // Repositories
        register(PostRepositoryProtocol.self) { [self] in
            PostRepository(
                networkService: resolve(NetworkServiceProtocol.self)
            )
        }
    }
}
