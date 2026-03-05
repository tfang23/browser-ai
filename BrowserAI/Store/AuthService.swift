//
//  AuthService.swift
//  BrowserAI
//
//  Authentication state management
//

import Foundation
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "currentUser"
    
    init() {
        // Check for existing session
        if let data = userDefaults.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signUp(email: String, phone: String?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await APIService.shared.createUser(email: email, phone: phone)
            self.currentUser = user
            self.isAuthenticated = true
            saveUser(user)
        } catch {
            errorMessage = "Failed to create account. Please try again."
        }
        
        isLoading = false
    }
    
    func refreshUser() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let user = try await APIService.shared.getUser(userId: userId)
            self.currentUser = user
            saveUser(user)
        } catch {
            print("Failed to refresh user: \(error)")
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        userDefaults.removeObject(forKey: userKey)
    }
    
    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            userDefaults.set(data, forKey: userKey)
        }
    }
}
