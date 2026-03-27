import Foundation

struct APIClient {
    private let baseURL: String
    private let token: String?

    init(baseURL: String = Config.apiBaseURL, token: String? = KeychainService.getToken()) {
        self.baseURL = baseURL
        self.token = token
    }

    func post<T: Encodable, U: Decodable>(_ path: String, body: T) async throws -> U {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode >= 400 {
            throw APIError.httpStatus(http.statusCode, data: data)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(U.self, from: data)
    }

    func get<U: Decodable>(_ path: String) async throws -> U {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode >= 400 {
            throw APIError.httpStatus(http.statusCode, data: data)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(U.self, from: data)
    }

    func patch<U: Decodable>(_ path: String) async throws -> U {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode >= 400 {
            throw APIError.httpStatus(http.statusCode, data: data)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(U.self, from: data)
    }

    func delete(_ path: String) async throws {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode >= 400 {
            throw APIError.httpStatus(http.statusCode, data: data)
        }
    }
}

// Session API types
struct SessionCreateRequest: Encodable {
    let mode: String
    let context: String?
    let etaMinutes: Int?
}

struct SessionResponse: Decodable {
    let id: String
    let mode: String
    let context: String?
    let etaMinutes: Int?
    let status: String
    let startedAt: String?
    let endedAt: String?

    init(id: String, mode: String, context: String?, etaMinutes: Int?, status: String, startedAt: String?, endedAt: String?) {
        self.id = id
        self.mode = mode
        self.context = context
        self.etaMinutes = etaMinutes
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

struct SessionEscalateRequest: Encodable {
    let trigger: String
}

struct SessionEscalateResponse: Decodable {
    let ok: Bool
    let sessionId: String
    let status: String
    let requestedState: String
    let trigger: String
}

enum APIError: Error {
    case invalidResponse
    case httpStatus(Int, data: Data)
}

// Auth API response types
struct AppleTokenRequest: Encodable {
    let identity_token: String
    let authorization_code: String?
}

struct PhoneRequestRequest: Encodable {
    let phone: String
}

struct PhoneVerifyRequest: Encodable {
    let phone: String
    let code: String
}

struct AuthResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let user: UserResponse
}

struct UserResponse: Decodable {
    let id: String
    let email: String?
    let phone: String?
    let createdAt: String?
}

struct PhoneRequestResponse: Decodable {
    let message: String
    let expiresIn: Int
}

// Guardian API types
struct GuardianResponse: Decodable {
    let id: String
    let name: String
    let phone: String
    let priority: Int
}

struct GuardianCreateRequest: Encodable {
    let name: String
    let phone: String
    let priority: Int
}

// Saved location API types
struct SavedLocationResponse: Decodable {
    let id: String
    let kind: String
    let name: String
    let latitude: Double?
    let longitude: Double?
}

struct LocationCreateRequest: Encodable {
    let kind: String
    let name: String
    let latitude: Double?
    let longitude: Double?
}
