import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Thin async HTTP client for the Musix API.
final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var token: String? {
        didSet {
            if let token { Keychain.save(token, "musix.token") } else { Keychain.delete("musix.token") }
        }
    }

    init(baseURL: URL = Config.apiBaseURL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)

        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = d

        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = e

        self.token = Keychain.read("musix.token")
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await send(method: "GET", path: path, query: query, body: nil)
    }

    func post<T: Decodable>(_ path: String) async throws -> T {
        try await send(method: "POST", path: path, query: [:], body: Data("{}".utf8))
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let data = try encoder.encode(body)
        return try await send(method: "POST", path: path, query: [:], body: data)
    }

    // MARK: - Core

    private func send<T: Decodable>(method: String,
                                    path: String,
                                    query: [String: String],
                                    body: Data?) async throws -> T {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                             resolvingAgainstBaseURL: false) else {
            throw APIError(message: "Invalid request URL.")
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError(message: "Invalid request URL.") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError(message: "Unexpected response from server.")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError(message: Self.errorMessage(in: data) ?? "Request failed (\(http.statusCode)).")
            }
            return try decoder.decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
        } catch let error as APIError {
            throw error
        } catch is DecodingError {
            throw APIError(message: "The server sent something unexpected. Please try again.")
        } catch {
            throw APIError(message: "Can't reach Musix right now. Check your connection and try again.")
        }
    }

    private static func errorMessage(in data: Data) -> String? {
        struct ErrorBody: Decodable {
            let error: String?
            let message: String?
        }
        guard let body = try? JSONDecoder().decode(ErrorBody.self, from: data) else { return nil }
        return body.error ?? body.message
    }
}
