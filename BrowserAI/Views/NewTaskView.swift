//
//  NewTaskView.swift
//  BrowserAI
//
//  Task creation with cost estimation
//

import SwiftUI

struct NewTaskView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss
    
    var initialType: TaskType?
    
    @State private var selectedType: TaskType = .restaurant
    @State private var goal = ""
    @State private var details = ""
    @State private var selectedFrequency = 30
    @State private var durationDays = 7
    
    @State private var frequencyOptions: [FrequencyOption] = []
    @State private var costEstimate: CostEstimate?
    
    @State private var isLoading = false
    @State private var showingConfirmation = false
    @State private var showingInsufficientTokens = false
    
    var body: some View {
        NavigationView {
            Form {
                // Task Type Section
                Section("What do you need?") {
                    Picker("Task Type", selection: $selectedType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Goal Section
                Section("Goal") {
                    TextField("e.g., Book a table at French Laundry", text: $goal)
                    
                    TextEditor(text: $details)
                        .frame(minHeight: 80)
                        .placeholder(when: details.isEmpty) {
                            Text("Additional details (party size, preferred dates, etc.)")
                                .foregroundStyle(.secondary)
                        }
                }
                
                // Frequency Section
                Section("Check Frequency") {
                    if frequencyOptions.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Picker("How often to check", selection: $selectedFrequency) {
                            ForEach(frequencyOptions, id: \.minutes) { option in
                                HStack {
                                    Text(option.label)
                                    Spacer()
                                    Text("~\(option.displayPrice)")
                                        .foregroundStyle(.secondary)
                                }
                                .tag(option.minutes)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        
                        Text("\(selectedFrequency) min checks for \(durationDays) days = ~\(estimatedChecks) total checks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Duration Section
                Section("Monitor For") {
                    Stepper("\(durationDays) days", value: $durationDays, in: 1...30)
                    
                    Text("We'll stop checking after \(durationDays) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Cost Estimate Section
                if let estimate = costEstimate {
                    Section("Estimated Cost") {
                        HStack {
                            Text("Total Tokens")
                            Spacer()
                            Text("\(estimate.estimatedTotalTokens)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Estimated Price")
                            Spacer()
                            Text(String(format: "$%.2f", estimate.usdEstimate))
                                .fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                        }
                        
                        if estimate.canAfford {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("You have enough tokens")
                                    .font(.caption)
                            }
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Insufficient tokens")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Create Button
                Section {
                    Button(action: createTask) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Create Task")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(goal.isEmpty || isLoading || costEstimate == nil)
                    .listRowBackground(Color.indigo)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let initial = initialType {
                    selectedType = initial
                }
                loadFrequencyOptions()
            }
            .onChange(of: selectedFrequency) { _ in updateEstimate() }
            .onChange(of: durationDays) { _ in updateEstimate() }
            .onChange(of: selectedType) { _ in 
                loadFrequencyOptions()
                updateEstimate()
            }
            .sheet(isPresented: $showingInsufficientTokens) {
                InsufficientTokensSheet(estimate: costEstimate)
            }
        }
    }
    
    private var estimatedChecks: Int {
        let totalMinutes = durationDays * 24 * 60
        return totalMinutes / selectedFrequency
    }
    
    private func loadFrequencyOptions() {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            let options = await taskStore.getFrequencyOptions(userId: userId, type: selectedType)
            await MainActor.run {
                self.frequencyOptions = options
                if let first = options.first {
                    self.selectedFrequency = first.minutes
                }
                updateEstimate()
            }
        }
    }
    
    private func updateEstimate() {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            let estimate = await taskStore.getCostEstimate(
                userId: userId,
                type: selectedType,
                frequency: selectedFrequency,
                duration: durationDays
            )
            await MainActor.run {
                self.costEstimate = estimate
            }
        }
    }
    
    private func createTask() {
        guard let userId = authService.currentUser?.id,
              let estimate = costEstimate else { return }
        
        if !estimate.canAfford {
            showingInsufficientTokens = true
            return
        }
        
        isLoading = true
        
        Task {
            let context: [String: Any] = [
                "details": details,
                "party_size": extractPartySize(from: goal + details),
            ]
            
            _ = await taskStore.createTask(
                userId: userId,
                type: selectedType,
                goal: goal,
                frequency: selectedFrequency,
                context: context
            )
            
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        }
    }
    
    private func extractPartySize(from text: String) -> Int {
        // Simple extraction - in production use NLP
        if text.contains("party of 4") || text.contains("4 people") {
            return 4
        } else if text.contains("party of 2") || text.contains("2 people") {
            return 2
        }
        return 2 // Default
    }
}

// MARK: - Insufficient Tokens Sheet

struct InsufficientTokensSheet: View {
    let estimate: CostEstimate?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                
                Text("Insufficient Tokens")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let estimate = estimate {
                    VStack(spacing: 12) {
                        Text("This task requires \(estimate.estimatedTotalTokens) tokens")
                            .foregroundStyle(.secondary)
                        
                        Text("You need more tokens to start this task")
                            .font(.subheadline)
                    }
                }
                
                Button(action: {
                    dismiss()
                    // Navigate to token shop
                }) {
                    Text("Buy Tokens")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - TextEditor Placeholder

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
