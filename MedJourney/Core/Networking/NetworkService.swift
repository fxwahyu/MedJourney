//
//  NetworkService.swift
//  MedJourney
//
//  Core Networking Layer — Concrete URLSession-based implementation
//

import Foundation

/// Production implementation of `NetworkServiceProtocol` using `URLSession`.
///
/// Handles:
/// - Building URLRequests from `APIEndpoint`
/// - HTTP status code validation
/// - JSON decoding with configurable `JSONDecoder`
/// - Error mapping to `NetworkError`
///
/// The `URLSession` and `JSONDecoder` are injected via init for testability.
final class NetworkService: NetworkServiceProtocol {

    // MARK: - Properties

    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Initialization

    /// Creates a new `NetworkService`.
    ///
    /// - Parameters:
    ///   - session: The URLSession to use. Defaults to `.shared`.
    ///   - decoder: The JSON decoder to use. Defaults to a decoder configured
    ///              for `convertFromSnakeCase` key strategy.
    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    ) {
        self.session = session
        self.decoder = decoder
    }

    // MARK: - NetworkServiceProtocol

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await requestData(endpoint)

        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodingError {
            throw NetworkError.decodingFailed(decodingError.localizedDescription)
        }
    }

    func requestData(_ endpoint: APIEndpoint) async throws -> Data {
        let urlRequest: URLRequest

        do {
            urlRequest = try endpoint.asURLRequest()
        } catch {
            throw error as? NetworkError ?? NetworkError.invalidURL
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        try validateStatusCode(httpResponse.statusCode)

        return data
    }

    // MARK: - Private Helpers

    /// Maps URLError codes to domain-specific `NetworkError` cases.
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .noConnection
        case .timedOut:
            return .requestFailed("The request timed out. Please try again.")
        case .cancelled:
            return .requestFailed("The request was cancelled.")
        default:
            return .requestFailed(error.localizedDescription)
        }
    }

    /// Validates HTTP status codes and throws appropriate errors.
    private func validateStatusCode(_ statusCode: Int) throws {
        switch statusCode {
        case 200...299:
            return // Success range — no error
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            throw NetworkError.serverError(statusCode: statusCode)
        case 500...599:
            throw NetworkError.serverError(statusCode: statusCode)
        default:
            throw NetworkError.unknown("Unexpected status code: \(statusCode)")
        }
    }
}
