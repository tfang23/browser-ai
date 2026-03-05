//
//  StoreKitService.swift
//  BrowserAI
//
//  In-App Purchase handling with StoreKit 2
//

import StoreKit
import Foundation

@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    
    private var updates: Task<Void, Never>? = nil
    
    // Product IDs must match App Store Connect
    let productIDs = [
        "com.browserai.tokens.starter",
        "com.browserai.tokens.standard",
        "com.browserai.tokens.power",
        "com.browserai.tokens.enterprise"
    ]
    
    private init() {
        // Listen for transaction updates
        updates = Task {
            for await update in Transaction.updates {
                await handleTransactionUpdate(update)
            }
        }
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIDs)
            // Sort by price
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product, userId: String) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Send receipt to backend
            if let receipt = transaction.jsonRepresentation {
                let receiptString = receipt.base64EncodedString()
                _ = try await APIService.shared.purchaseTokens(
                    userId: userId,
                    packageId: product.id,
                    receipt: receiptString
                )
            }
            
            await transaction.finish()
            purchasedProductIDs.insert(product.id)
            
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            // Waiting for approval (kids ask parent, etc.)
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func handleTransactionUpdate(_ update: TransactionUpdate) async {
        if case .verified(let transaction) = update {
            await transaction.finish()
            purchasedProductIDs.insert(transaction.productID)
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(let transaction, let error):
            print("Unverified transaction: \(transaction), error: \(error)")
            throw StoreKitError.failedVerification
        }
    }
    
    func product(for packageId: String) -> Product? {
        return products.first { $0.id == packageId }
    }
}

enum StoreKitError: Error {
    case failedVerification
    case productNotFound
}
