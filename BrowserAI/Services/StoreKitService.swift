//
//  StoreKitService.swift
//  BrowserAI
//
//  Production-ready in-app purchase handling
//

import StoreKit
import SwiftUI

@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Product IDs must match App Store Connect
    private let productIdentifiers = [
        "com.browserai.tokens.starter",
        "com.browserai.tokens.standard", 
        "com.browserai.tokens.power",
        "com.browserai.tokens.enterprise"
    ]
    
    private var updates: Task<Void, Never>?
    
    init() {
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
            products = try await Product.products(for: productIdentifiers)
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product, userId: String) async -> Transaction? {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Verify with backend
                if let receipt = transaction.jsonRepresentation {
                    let receiptString = receipt.base64EncodedString()
                    do {
                        let user = try await APIService.shared.purchaseTokens(
                            userId: userId,
                            packageId: product.id,
                            receipt: receiptString
                        )
                        // Update app state
                        await MainActor.run {
                            AppState().updateTokenBalance(user.tokenBalance)
                        }
                    } catch {
                        errorMessage = "Server verification failed"
                    }
                }
                
                await transaction.finish()
                return transaction
                
            case .userCancelled:
                return nil
                
            case .pending:
                errorMessage = "Purchase pending approval"
                return nil
                
            @unknown default:
                return nil
            }
            
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Restore
    
    func restorePurchases() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement {
                // Re-verify with backend if needed
                print("Restored: \(transaction.productID)")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func handleTransactionUpdate(_ update: TransactionUpdate) async {
        if case .verified(let transaction) = update {
            await transaction.finish()
            // Could post notification here
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }
    
    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = StoreKitService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("💰")
                        .font(.system(size: 48))
                    Text("Get Tokens")
                        .font(.title2.bold())
                    Text("Purchase tokens to power your AI agents")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
                
                // Current balance
                HStack {
                    Text("Current Balance")
                        .font(.subheadline)
                    Spacer()
                    Text("\(appState.tokenBalance) tokens")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Products
                ScrollView {
                    VStack(spacing: 12) {
                        if store.isLoading {
                            ProgressView()
                                .padding()
                        } else if store.products.isEmpty {
                            Text("Products not available")
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ForEach(store.products) { product in
                                ProductCard(product: product)
                                    .onTapGesture {
                                        Task {
                                            if let user = appState.user {
                                                let _ = await store.purchase(product, userId: user.id)
                                                dismiss()
                                            }
                                        }
                                    }
                            }
                        }
                    }
                    .padding()
                }
                
                // Restore button
                Button("Restore Purchases") {
                    Task {
                        await store.restorePurchases()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await store.loadProducts()
            }
            .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
                Button("OK") { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}

struct ProductCard: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(product.displayPrice)
                .font(.title3.bold())
                .foregroundStyle(.green)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
