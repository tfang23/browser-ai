//
//  WelcomeView.swift
//  BrowserAI
//
//  Onboarding and sign up
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var phone = ""
    @State private var isSigningUp = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.indigo.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Logo icon
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.system(size: 80))
                        .foregroundStyle(.indigo)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Browser AI")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        
                        Text("Your personal web agent")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Sign up form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        TextField("Phone (optional)", text: $phone)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                        
                        Button(action: signUp) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Get Started")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(email.isEmpty || authService.isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Free tokens badge
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.green)
                        Text("300 free tokens included")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Footer
                    Text("By signing up, you agree to our Terms and Privacy Policy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
    
    private func signUp() {
        Task {
            await authService.signUp(email: email, phone: phone.isEmpty ? nil : phone)
        }
    }
}

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}
