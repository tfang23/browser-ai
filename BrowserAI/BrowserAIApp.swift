//
//  BrowserAIApp.swift
//  BrowserAI
//
//  Production-ready iOS app for autonomous browser tasks
//

import SwiftUI
import StoreKit

@main
struct BrowserAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState())
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure appearance
        configureAppearance()
        
        // Register for notifications
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        
        return true
    }
    
    private func configureAppearance() {
        // Dark terminal theme throughout
        UINavigationBar.appearance().tintColor = .systemGreen
        UITextField.appearance().tintColor = .systemGreen
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

// MARK: - Notification Delegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        completionHandler()
    }
}

// MARK: - Global App State

@MainActor
class AppState: ObservableObject {
    @Published var user: User?
    @Published var tokenBalance: Int = 0
    @Published var isAuthenticated = false
    @Published var showPaywall = false
    
    private let apiService = APIService()
    private let keychain = KeychainService()
    
    init() {
        loadUser()
    }
    
    private func loadUser() {
        if let userId = keychain.getUserId(),
           let token = keychain.getAuthToken() {
            Task {
                await authenticate(userId: userId, token: token)
            }
        }
    }
    
    func authenticate(userId: String, token: String) async {
        keychain.saveUserId(userId)
        keychain.saveAuthToken(token)
        
        do {
            let user = try await apiService.getUser(userId: userId)
            self.user = user
            self.tokenBalance = user.tokenBalance
            self.isAuthenticated = true
        } catch {
            // Create new user if not found
            await createUser()
        }
    }
    
    func createUser() async {
        do {
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            let user = try await apiService.createUser(
                deviceId: deviceId,
                email: nil // Anonymous user initially
            )
            self.user = user
            self.tokenBalance = user.tokenBalance
            self.isAuthenticated = true
            keychain.saveUserId(user.id)
        } catch {
            print("Failed to create user: \(error)")
        }
    }
    
    func updateTokenBalance(_ newBalance: Int) {
        tokenBalance = newBalance
        user?.tokenBalance = newBalance
    }
    
    func deductTokens(_ amount: Int) {
        tokenBalance -= amount
        user?.tokenBalance = tokenBalance
    }
    
    func signOut() {
        keychain.clear()
        user = nil
        isAuthenticated = false
        tokenBalance = 0
    }
}
