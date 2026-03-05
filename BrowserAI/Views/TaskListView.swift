//
//  TaskListView.swift
//  BrowserAI
//
//  List of all tasks with filtering
//

import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var authService: AuthService
    
    @State private var selectedFilter: TaskFilter = .all
    @State private var showingNewTask = false
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
    }
    
    var filteredTasks: [AgentTask] {
        switch selectedFilter {
        case .all:
            return taskStore.tasks
        case .active:
            return taskStore.tasks.filter { 
                $0.status == .pending || $0.status == .monitoring || $0.status == .available || $0.status == .booking
            }
        case .completed:
            return taskStore.tasks.filter { 
                $0.status == .completed || $0.status == .failed || $0.status == .expired
            }
        }
    }
    
    var body: some View {
        List {
            // Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 8)
            
            if filteredTasks.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        Text("No \(selectedFilter.rawValue.lowercased()) tasks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(filteredTasks) { task in
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        TaskListRow(task: task)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewTask = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskView()
        }
        .onAppear {
            loadTasks()
        }
        .refreshable {
            await refreshTasks()
        }
    }
    
    private func loadTasks() {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            await taskStore.loadTasks(userId: userId)
        }
    }
    
    private func refreshTasks() async {
        guard let userId = authService.currentUser?.id else { return }
        await taskStore.loadTasks(userId: userId)
    }
}

struct TaskListRow: View {
    let task: AgentTask
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: task.type.icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(colorForType(task.type))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.goal)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(task.status.statusDisplay)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colorForStatus(task.status).opacity(0.15))
                        .foregroundStyle(colorForStatus(task.status))
                        .cornerRadius(4)
                    
                    if let lastCheck = task.lastCheckAt {
                        Text(timeAgo(from: lastCheck))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorForType(_ type: TaskType) -> Color {
        switch type {
        case .restaurant: return .orange
        case .ticket: return .pink
        case .retail: return .purple
        case .flight: return .blue
        case .hotel: return .teal
        case .other: return .gray
        }
    }
    
    private func colorForStatus(_ status: TaskStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .monitoring: return .blue
        case .available: return .orange
        case .booking: return .purple
        case .completed: return .green
        case .failed: return .red
        case .expired: return .gray
        }
    }
    
    private func timeAgo(from isoString: String) -> String {
        // Simplified - parse and format
        return "recently"
    }
}

// MARK: - Task Detail View

struct TaskDetailView: View {
    let task: AgentTask
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Header
                StatusHeader(task: task)
                
                // Task Info
                TaskInfoSection(task: task)
                
                // Check History
                if let lastCheck = task.lastCheckAt {
                    CheckHistorySection(lastCheck: lastCheck, result: task.lastCheckResult)
                }
                
                // Cost Info
                if let estimatedTokens = task.estimatedTokens {
                    CostSection(estimatedTokens: estimatedTokens)
                }
                
                // Actions
                ActionsSection(task: task)
            }
            .padding()
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatusHeader: View {
    let task: AgentTask
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: task.type.icon)
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            
            Text(task.status.statusDisplay)
                .font(.title2)
                .fontWeight(.bold)
            
            if task.status == .monitoring {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking every \(task.checkFrequencyMinutes) minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct TaskInfoSection: View {
    let task: AgentTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Information")
                .font(.headline)
            
            InfoRow(label: "Goal", value: task.goal)
            InfoRow(label: "Type", value: task.type.displayName)
            InfoRow(label: "Created", value: formatDate(task.createdAt))
            
            if let expires = task.expiresAt {
                InfoRow(label: "Expires", value: formatDate(expires))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func formatDate(_ isoString: String) -> String {
        // Simplified formatting
        return isoString.prefix(10).description
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct CheckHistorySection: View {
    let lastCheck: String
    let result: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Check")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Checked at")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastCheck.prefix(16).description)
                        .font(.subheadline)
                }
                
                Spacer()
                
                if let result = result {
                    Text(result)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct CostSection: View {
    let estimatedTokens: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost")
                .font(.headline)
            
            HStack {
                Text("Estimated tokens")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(estimatedTokens)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("~USD")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(String(format: "$%.2f", Double(estimatedTokens) * 0.01))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.indigo)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct ActionsSection: View {
    let task: AgentTask
    
    var body: some View {
        VStack(spacing: 12) {
            if task.status == .monitoring || task.status == .pending {
                Button(action: {
                    // Cancel task
                }) {
                    Text("Cancel Task")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
            }
            
            if task.status == .completed {
                Button(action: {
                    // Share/Export
                }) {
                    Text("Share Result")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
}
