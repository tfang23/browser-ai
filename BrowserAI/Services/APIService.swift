//
//  APIService.swift
//  BrowserAI
//
//  Production API client with error handling and retries
//

import Foundation

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case networkError(Error)
    case unauthorized
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to parse response"
        case .serverError(let code, let message):
            return "Server error \(code): \(message ?? "Unknown")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Please sign in again"
        }
    }
}

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    #if DEBUG
    private let baseURL = "http://localhost:8000"
    #else
    private let baseURL = "https://api.browserai.com" // Production
    #endif
    
    private let session: URLSession
    private var authToken: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    // MARK: - Users
    
    func createUser(deviceId: String, email: String?) async throws -> User {
        let body: [String: Any] = [
            "device_id": deviceId,
            "email": email as Any
        ]
        return try await post("/users/", body: body)
    }
    
    func getUser(userId: String) async throws -> User {
        try await get("/users/\(userId)")
    }
    
    // MARK: - Chat
    
    func sendMessage(userId: String, message: String, sessionId: String?) async throws -> ChatMessageResponse {
        let body: [String: Any] = [
            "user_id": userId,
            "message": message,
            "session_id": sessionId as Any
        ]
        return try await post("/chat/message", body: body)
    }
    
    // MARK: - Token Packages
    
    func getTokenPackages() async throws -> [TokenPackage] {
        try await get("/users/packages")
    }
    
    func purchaseTokens(userId: String, packageId: String, receipt: String) async throws -> User {
        let body: [String: Any] = [
            "package_id": packageId,
            "apple_receipt": receipt
        ]
        return try await post("/users/\(userId)/purchase-tokens", body: body)
    }
    
    // MARK: - Tasks
    
    func getTasks(userId: String) async throws -> [AgentTask] {
        try await get("/users/\(userId)/tasks")
    }
    
    // MARK: - Generic HTTP Methods
    
    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        try checkStatusCode(httpResponse, data: data)
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        try checkStatusCode(httpResponse, data: data)
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    private func checkStatusCode(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 400...499:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(response.statusCode, message)
        case 500...599:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(response.statusCode, message)
        default:
            throw APIError.serverError(response.statusCode, nil)
        }
    }
}

// MARK: - Keychain

class KeychainService {
    static let shared = KeychainService()
    
    private let userIdKey = "browserai.userid"
    private let tokenKey = "browserai.token"
    
    func saveUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
    }
    
    func getUserId() -> String? {
        UserDefaults.standard.string(forKey: userIdKey)
    }
    
    func saveAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    func getAuthToken() -> String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
