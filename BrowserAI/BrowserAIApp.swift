//
//  BrowserAIApp.swift
//  BrowserAI
//
//  Main app entry point
//

import SwiftUI

@main
struct BrowserAIApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var tokenStore = TokenStore()
    @StateObject private var taskStore = TaskStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(tokenStore)
                .environmentObject(taskStore)
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }
                .tag(1)
            
            TokenShopView()
                .tabItem {
                    Label("Tokens", systemImage: "dollarsign.circle.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(.indigo)
    }
}
