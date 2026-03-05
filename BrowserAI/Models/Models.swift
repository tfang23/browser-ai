//
//  Models.swift
//  BrowserAI
//
//  Data models for the app
//

import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let phone: String?
    var tokenBalance: Int
    let createdAt: String
    
    var formattedBalance: String {
        return "\(tokenBalance)"
    }
}

// MARK: - Task

enum TaskStatus: String, Codable {
    case pending = "pending"
    case monitoring = "monitoring"
    case available = "available"
    case booking = "booking"
    case completed = "completed"
    case failed = "failed"
    case expired = "expired"
}

enum TaskType: String, Codable, CaseIterable {
    case restaurant = "restaurant"
    case ticket = "ticket"
    case retail = "retail_drop"
    case flight = "flight"
    case hotel = "hotel"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .restaurant: return "Restaurant"
        case .ticket: return "Tickets"
        case .retail: return "Limited Drop"
        case .flight: return "Flight"
        case .hotel: return "Hotel"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .ticket: return "ticket.fill"
        case .retail: return "shoe.fill"
        case .flight: return "airplane"
        case .hotel: return "bed.double.fill"
        case .other: return "star.fill"
        }
    }
}

struct AgentTask: Codable, Identifiable {
    let id: String
    let userId: String
    let type: TaskType
    let goal: String
    let status: TaskStatus
    let checkFrequencyMinutes: Int
    let createdAt: String
    let expiresAt: String?
    let estimatedTokens: Int?
    let lastCheckAt: String?
    let lastCheckResult: String?
    
    var statusDisplay: String {
        switch status {
        case .pending: return "Starting..."
        case .monitoring: return "Monitoring"
        case .available: return "Available!"
        case .booking: return "Booking..."
        case .completed: return "Done"
        case .failed: return "Failed"
        case .expired: return "Expired"
        }
    }
    
    var statusColor: String {
        switch status {
        case .pending: return "gray"
        case .monitoring: return "blue"
        case .available: return "orange"
        case .booking: return "purple"
        case .completed: return "green"
        case .failed: return "red"
        case .expired: return "gray"
        }
    }
}

// MARK: - Token Package

struct TokenPackage: Codable, Identifiable {
    let id: String
    let name: String
    let tokenAmount: Int
    let bonusTokens: Int
    let priceUSD: Double
    
    var totalTokens: Int {
        tokenAmount + bonusTokens
    }
    
    var displayPrice: String {
        String(format: "$%.2f", priceUSD)
    }
    
    var displayTokens: String {
        if bonusTokens > 0 {
            return "\(tokenAmount) + \(bonusTokens) bonus"
        }
        return "\(tokenAmount)"
    }
}

// MARK: - Credential

enum CredentialType: String, Codable {
    case password = "password"
    case personal = "personal"
    case payment = "payment"
    case apiKey = "api_key"
}

struct Credential: Codable, Identifiable {
    let id: String
    let serviceName: String
    let type: CredentialType
    let createdAt: String
}

// MARK: - Cost Estimate

struct CostEstimate: Codable {
    let estimatedTotalTokens: Int
    let numChecks: Int
    let breakdown: CostBreakdown
    let usdEstimate: Double
    let canAfford: Bool
    let recommendedPackages: [RecommendedPackage]
}

struct CostBreakdown: Codable {
    let monitoringCost: Int
    let availabilityChecksCost: Int
    let bookingCost: Int
    let buffer: Int
}

struct RecommendedPackage: Codable {
    let packageId: String
    let name: String
    let totalTokens: Int
    let priceUSD: Double
    let coversTask: Bool
}

// MARK: - Frequency Option

struct FrequencyOption: Codable, Identifiable {
    let id = UUID()
    let minutes: Int
    let label: String
    let risk: String
    let estimatedTokens: Int
    let estimatedUSD: Double
    
    var displayPrice: String {
        String(format: "$%.2f", estimatedUSD)
    }
}
