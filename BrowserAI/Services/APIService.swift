//
//  APIService.swift
//  BrowserAI
//
//  API client for backend communication
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = URL(string: "https://your-api-url.com")!
    private var authToken: String?
    
    private init() {}
    
    // MARK: - Authentication
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    // MARK: - Users
    
    func createUser(email: String, phone: String?) async throws -> User {
        let body = ["email": email, "phone": phone]
        return try await post("/users/", body: body)
    }
    
    func getUser(userId: String) async throws -> User {
        return try await get("/users/\(userId)")
    }
    
    // MARK: - Tasks
    
    func createTask(userId: String, type: TaskType, goal: String, frequency: Int, context: [String: Any]) async throws -> AgentTask {
        let body: [String: Any] = [
            "user_id": userId,
            "task_type": type.rawValue,
            "goal": goal,
            "check_frequency_minutes": frequency,
            "context": context
        ]
        return try await post("/tasks/persistent", body: body)
    }
    
    func getTasks(userId: String) async throws -> [AgentTask] {
        return try await get("/users/\(userId)/tasks")
    }
    
    func estimateCost(userId: String, taskType: TaskType, frequency: Int, duration: Int) async throws -> CostEstimate {
        let body: [String: Any] = [
            "task_type": taskType.rawValue,
            "check_frequency_minutes": frequency,
            "max_duration_days": duration
        ]
        return try await post("/users/\(userId)/estimate-tokens", body: body)
    }
    
    func getFrequencyOptions(userId: String, taskType: TaskType) async throws -> [FrequencyOption] {
        return try await get("/users/\(userId)/frequency-options?task_type=\(taskType.rawValue)")
    }
    
    // MARK: - Credentials
    
    func storeCredentials(userId: String, service: String, type: CredentialType, data: [String: Any]) async throws -> Credential {
        let body: [String: Any] = [
            "service_name": service,
            "credential_type": type.rawValue,
            "data": data
        ]
        return try await post("/users/\(userId)/credentials", body: body)
    }
    
    func getCredentials(userId: String) async throws -> [Credential] {
        return try await get("/users/\(userId)/credentials")
    }
    
    // MARK: - Token Packages
    
    func getTokenPackages() async throws -> [TokenPackage] {
        return try await get("/users/packages")
    }
    
    func purchaseTokens(userId: String, packageId: String, receipt: String) async throws -> User {
        let body: [String: Any] = [
            "package_id": packageId,
            "apple_receipt": receipt
        ]
        return try await post("/users/\(userId)/purchase-tokens", body: body)
    }
    
    // MARK: - Generic HTTP Methods
    
    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum APIError: Error {
    case invalidResponse
    case decodingError
    case networkError
}
