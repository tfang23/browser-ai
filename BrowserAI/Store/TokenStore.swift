//
//  TokenStore.swift
//  BrowserAI
//
//  Token balance and purchase management
//

import Foundation
import Combine

@MainActor
class TokenStore: ObservableObject {
    @Published var packages: [TokenPackage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storeKit = StoreKitService.shared
    
    func loadPackages() async {
        isLoading = true
        
        // Load from StoreKit and API
        await storeKit.loadProducts()
        
        do {
            packages = try await APIService.shared.getTokenPackages()
        } catch {
            errorMessage = "Failed to load packages"
        }
        
        isLoading = false
    }
    
    func purchasePackage(_ package: TokenPackage, userId: String) async -> Bool {
        guard let product = storeKit.product(for: package.id) else {
            errorMessage = "Product not available"
            return false
        }
        
        do {
            let _ = try await storeKit.purchase(product, userId: userId)
            return true
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }
    
    func formatTokenBalance(_ balance: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: balance)) ?? "\(balance)"
    }
}
