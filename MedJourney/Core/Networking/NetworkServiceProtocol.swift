//
//  NetworkServiceProtocol.swift
//  MedJourney
//
//  Core Networking Layer — Service abstraction protocol
//

import Foundation

/// Defines the contract for performing network requests.
///
/// ViewModels and Repositories depend on this protocol rather than a
/// concrete implementation, enabling:
/// - Easy mocking in unit tests
/// - Swapping implementations (e.g., URLSession vs. Alamofire)
/// - Dependency injection via `DependencyContainer`
///
/// Usage:
/// ```swift
/// class MyRepository {
///     private let networkService: NetworkServiceProtocol
///
///     init(networkService: NetworkServiceProtocol) {
///         self.networkService = networkService
///     }
///
///     func fetchUsers() async throws -> [User] {
///         try await networkService.request(UserEndpoint.list)
///     }
/// }
/// ```
protocol NetworkServiceProtocol {

    /// Performs a network request and decodes the response into the specified type.
    ///
    /// - Parameter endpoint: The API endpoint describing the request.
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `NetworkError` if the request fails at any stage.
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T

    /// Performs a network request and returns raw response data.
    ///
    /// Use this for non-JSON responses (e.g., file downloads, images).
    ///
    /// - Parameter endpoint: The API endpoint describing the request.
    /// - Returns: The raw response `Data`.
    /// - Throws: `NetworkError` if the request fails.
    func requestData(_ endpoint: APIEndpoint) async throws -> Data
}
