//
//  Models.swift
//  BrowserAI
//
//  Data models for API communication
//

import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    var tokenBalance: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case tokenBalance = "token_balance"
        case createdAt = "created_at"
    }
}

// MARK: - Chat

struct ChatMessageRequest: Codable {
    let userId: String
    let message: String
    let sessionId: String?
}

struct ChatMessageResponse: Codable {
    let sessionId: String
    let response: String
    let state: String
    let result: TaskResult?
    let actions: [ChatAction]?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case response, state, result, actions
    }
}

struct TaskResult: Codable {
    let success: Bool
    let summary: String?
    let error: String?
}

struct ChatAction: Codable, Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

// MARK: - Terminal Line

struct TerminalLine: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let content: String
    let type: LineType
    
    enum LineType: Equatable {
        case welcome
        case input(String)  // the raw input text
        case output(OutputType)
        case actionButtons([ChatAction])
        
        enum OutputType: Equatable {
            case normal
            case success
            case error
            case warning
            case info
            case dim
        }
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
    
    static func == (lhs: TerminalLine, rhs: TerminalLine) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Token Package

struct TokenPackage: Codable, Identifiable {
    let id: String
    let name: String
    let tokenAmount: Int
    let bonusTokens: Int
    let priceUSD: Double
    
    var totalTokens: Int { tokenAmount + bonusTokens }
    var displayPrice: String { String(format: "$%.2f", priceUSD) }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tokenAmount = "token_amount"
        case bonusTokens = "bonus_tokens"
        case priceUSD = "price_usd"
    }
}

// MARK: - Task

struct AgentTask: Codable, Identifiable {
    let id: String
    let userId: String
    let goal: String
    let status: TaskStatus
    let createdAt: Date
    let checkFrequencyMinutes: Int?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case goal, status
        case createdAt = "created_at"
        case checkFrequencyMinutes = "check_frequency_minutes"
        case expiresAt = "expires_at"
    }
}

enum TaskStatus: String, Codable {
    case pending = "pending"
    case monitoring = "monitoring"
    case available = "available"
    case booking = "booking"
    case completed = "completed"
    case failed = "failed"
    case expired = "expired"
    
    var displayText: String {
        switch self {
        case .pending: return "Starting..."
        case .monitoring: return "Monitoring"
        case .available: return "Available!"
        case .booking: return "Booking..."
        case .completed: return "Done"
        case .failed: return "Failed"
        case .expired: return "Expired"
        }
    }
}

// MARK: - Cost Estimate

struct CostEstimate: Codable {
    let estimatedTotalTokens: Int
    let numChecks: Int
    let usdEstimate: Double
    let canAfford: Bool
    
    enum CodingKeys: String, CodingKey {
        case estimatedTotalTokens = "estimated_total_tokens"
        case numChecks = "num_checks"
        case usdEstimate = "usd_estimate"
        case canAfford = "can_afford"
    }
}
