//
//  ProfileView.swift
//  BrowserAI
//
//  User profile, credentials, settings
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingSignOutConfirmation = false
    @State private var showingAddCredential = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                if let user = authService.currentUser {
                    ProfileHeader(user: user)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                
                // Credentials Section
                Section("Saved Information") {
                    NavigationLink(destination: CredentialsListView()) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.indigo)
                            Text("My Credentials")
                        }
                    }
                    
                    Button(action: { showingAddCredential = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("Add Credentials")
                        }
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: .constant(true))
                    Toggle("Email Updates", isOn: .constant(false))
                }
                
                // About Section
                Section("About") {
                    NavigationLink(destination: Text("Help & Support")) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink(destination: Text("Privacy Policy")) {
                        Label("Privacy Policy", systemImage: "doc.text")
                    }
                    
                    NavigationLink(destination: Text("Terms of Service")) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Sign Out
                Section {
                    Button(action: { showingSignOutConfirmation = true }) {
                        Text("Sign Out")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out?", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } message: {
                Text("You will need to sign in again to use the app.")
            }
            .sheet(isPresented: $showingAddCredential) {
                AddCredentialView()
            }
        }
    }
}

// MARK: - Profile Header

struct ProfileHeader: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Text(String(user.email.prefix(1).uppercased()))
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.indigo)
            }
            
            // Email
            Text(user.email)
                .font(.headline)
            
            // Token Balance
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.indigo)
                Text("\(user.tokenBalance) tokens")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Credentials List View

struct CredentialsListView: View {
    @State private var credentials: [Credential] = []
    @State private var isLoading = false
    
    var body: some View {
        List {
            if credentials.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        Text("No saved credentials")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Add credentials to speed up bookings")
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(credentials) { credential in
                    CredentialRow(credential: credential)
                }
            }
            
            Section {
                Button(action: {
                    // Add credential
                }) {
                    Label("Add New Credentials", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Credentials")
        .onAppear {
            loadCredentials()
        }
    }
    
    private func loadCredentials() {
        // Load from API
    }
}

struct CredentialRow: View {
    let credential: Credential
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForService(credential.serviceName))
                .font(.system(size: 20))
                .foregroundStyle(.indigo)
                .frame(width: 40, height: 40)
                .background(Color.indigo.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(credential.serviceName.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(credential.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func iconForService(_ service: String) -> String {
        switch service.lowercased() {
        case "tock": return "fork.knife"
        case "resy": return "fork.knife"
        case "nike": return "shoe.fill"
        case "ticketmaster": return "ticket.fill"
        default: return "key.fill"
        }
    }
}

// MARK: - Add Credential View

struct AddCredentialView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var serviceName = ""
    @State private var selectedType: CredentialType = .personal
    @State private var fields: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Service") {
                    TextField("Service Name (e.g., Tock, Nike)", text: $serviceName)
                    
                    Picker("Type", selection: $selectedType) {
                        Text("Personal Info").tag(CredentialType.personal)
                        Text("Password").tag(CredentialType.password)
                        Text("API Key").tag(CredentialType.apiKey)
                    }
                }
                
                Section("Information") {
                    if selectedType == .personal {
                        TextField("Full Name", text: binding(for: "name"))
                        TextField("Phone Number", text: binding(for: "phone"))
                            .keyboardType(.phonePad)
                        TextField("Email", text: binding(for: "email"))
                            .keyboardType(.emailAddress)
                        TextField("Address (optional)", text: binding(for: "address"))
                    } else if selectedType == .password {
                        SecureField("Username", text: binding(for: "username"))
                        SecureField("Password", text: binding(for: "password"))
                    }
                }
                
                Section {
                    Text("This information is encrypted and only used by your AI agent to complete tasks on your behalf.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Credentials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCredential()
                    }
                    .disabled(serviceName.isEmpty)
                }
            }
        }
    }
    
    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { fields[key] ?? "" },
            set: { fields[key] = $0 }
        )
    }
    
    private func saveCredential() {
        // Send to API
        dismiss()
    }
}
