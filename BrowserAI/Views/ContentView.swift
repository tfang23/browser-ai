//
//  ContentView.swift
//  BrowserAI
//
//  Root view with auth/terminal switching
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                TerminalView()
                    .environmentObject(appState)
            } else {
                WelcomeView()
                    .environmentObject(appState)
            }
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.051, green: 0.067, blue: 0.086)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Text("🌐")
                    .font(.system(size: 80))
                
                // Title
                VStack(spacing: 8) {
                    Text("Browser AI")
                        .font(.system(.largeTitle, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(Color(red: 0.345, green: 0.651, blue: 1.0))
                    
                    Text("Autonomous web agents")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(Color(red: 0.545, green: 0.580, blue: 0.619))
                }
                
                // Features
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "🤖", text: "Book restaurants & tickets")
                    FeatureRow(icon: "⏱️", text: "Monitor for days until available")
                    FeatureRow(icon: "⚡", text: "Auto-complete purchases")
                    FeatureRow(icon: "🔐", text: "Secure credential storage")
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
                
                Spacer()
                
                // CTA
                VStack(spacing: 16) {
                    Button(action: start) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text("Get Started")
                                .font(.system(.headline, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.137, green: 0.525, blue: 0.212))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    
                    Text("300 free tokens included")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Color(red: 0.494, green: 0.906, blue: 0.529))
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
    }
    
    private func start() {
        isLoading = true
        Task {
            await appState.createUser()
            isLoading = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color(red: 0.788, green: 0.820, blue: 0.851))
            Spacer()
        }
    }
}
