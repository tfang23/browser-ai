//
//  TokenShopView.swift
//  BrowserAI
//
//  Token purchase with Apple Pay / In-App Purchase
//

import SwiftUI
import StoreKit

struct TokenShopView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var tokenStore: TokenStore
    
    @State private var selectedPackage: TokenPackage?
    @State private var isPurchasing = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    TokenShopHeader()
                    
                    // Current Balance
                    if let user = authService.currentUser {
                        CurrentBalanceCard(balance: user.tokenBalance)
                    }
                    
                    // Packages
                    PackagesGrid(
                        selectedPackage: $selectedPackage,
                        isPurchasing: isPurchasing
                    )
                    
                    // Restore Button
                    Button("Restore Purchases") {
                        restorePurchases()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    
                    // Terms
                    Text("Subscriptions automatically renew unless cancelled. Manage in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Get Tokens")
            .onAppear {
                loadPackages()
            }
            .sheet(item: $selectedPackage) { package in
                PurchaseConfirmationSheet(
                    package: package,
                    isPurchasing: $isPurchasing,
                    onConfirm: { purchase(package) }
                )
            }
            .alert("Purchase Successful!", isPresented: $showingSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your tokens have been added to your account.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func loadPackages() {
        Task {
            await tokenStore.loadPackages()
        }
    }
    
    private func purchase(_ package: TokenPackage) {
        guard let userId = authService.currentUser?.id else { return }
        
        isPurchasing = true
        
        Task {
            let success = await tokenStore.purchasePackage(package, userId: userId)
            
            await MainActor.run {
                isPurchasing = false
                selectedPackage = nil
                
                if success {
                    showingSuccess = true
                    // Refresh user to get new balance
                    await authService.refreshUser()
                } else if let error = tokenStore.errorMessage {
                    self.errorMessage = error
                }
            }
        }
    }
    
    private func restorePurchases() {
        Task {
            await StoreKitService.shared.restorePurchases()
            await authService.refreshUser()
        }
    }
}

// MARK: - Header

struct TokenShopHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.indigo)
            
            Text("Token Packages")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Buy tokens to power your AI agents")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Current Balance

struct CurrentBalanceCard: View {
    let balance: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(balance)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.indigo)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Packages Grid

struct PackagesGrid: View {
    @EnvironmentObject var tokenStore: TokenStore
    @Binding var selectedPackage: TokenPackage?
    let isPurchasing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a Package")
                .font(.headline)
                .padding(.horizontal)
            
            if tokenStore.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(tokenStore.packages) { package in
                    PackageCard(
                        package: package,
                        isSelected: selectedPackage?.id == package.id,
                        isPurchasing: isPurchasing
                    )
                    .onTapGesture {
                        if !isPurchasing {
                            selectedPackage = package
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct PackageCard: View {
    let package: TokenPackage
    let isSelected: Bool
    let isPurchasing: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Token amount
            VStack(alignment: .leading, spacing: 4) {
                Text("\(package.totalTokens)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                if package.bonusTokens > 0 {
                    Text("+\(package.bonusTokens) bonus")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .frame(width: 100)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(package.name)
                    .font(.headline)
                
                Text("~\(estimatedTasks) tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(package.displayPrice)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.indigo)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.indigo : Color.clear, lineWidth: 2)
        )
        .opacity(isPurchasing ? 0.6 : 1.0)
    }
    
    private var estimatedTasks: Int {
        // Rough estimate: average task uses ~200 tokens
        return max(1, package.totalTokens / 200)
    }
}

// MARK: - Purchase Confirmation Sheet

struct PurchaseConfirmationSheet: View {
    let package: TokenPackage
    @Binding var isPurchasing: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Package summary
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.indigo)
                    
                    Text(package.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(package.totalTokens) tokens")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Text(package.displayPrice)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.indigo)
                }
                
                Spacer()
                
                // Purchase Button
                Button(action: onConfirm) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Buy with Apple Pay")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 32)
                
                // Cancel Button
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.secondary)
                
                Spacer()
            }
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isPurchasing)
                }
            }
        }
    }
}
