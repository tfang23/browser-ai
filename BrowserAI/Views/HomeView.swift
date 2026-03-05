//
//  HomeView.swift
//  BrowserAI
//
//  Main dashboard with token balance and quick actions
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var taskStore: TaskStore
    
    @State private var showingNewTask = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Token Balance Card
                    TokenBalanceCard()
                        .padding(.horizontal)
                    
                    // Quick Actions
                    QuickActionsGrid()
                        .padding(.horizontal)
                    
                    // Recent Tasks
                    RecentTasksSection()
                        .padding(.horizontal)
                    
                    // Tips
                    TipsSection()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .sheet(isPresented: $showingNewTask) {
                NewTaskView()
            }
        }
    }
}

// MARK: - Token Balance Card

struct TokenBalanceCard: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Token Balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let user = authService.currentUser {
                        Text("\(user.tokenBalance)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.indigo)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Navigate to token shop
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.indigo)
                }
            }
            
            if let user = authService.currentUser, user.tokenBalance < 100 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Running low! Buy more tokens.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Quick Actions Grid

struct QuickActionsGrid: View {
    @State private var showingNewTask = false
    @State private var selectedTaskType: TaskType?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start a Task")
                .font(.headline)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: columns, spacing: 12) {
                QuickActionButton(
                    icon: "fork.knife",
                    title: "Restaurant",
                    color: .orange,
                    action: { selectedTaskType = .restaurant }
                )
                
                QuickActionButton(
                    icon: "ticket.fill",
                    title: "Tickets",
                    color: .pink,
                    action: { selectedTaskType = .ticket }
                )
                
                QuickActionButton(
                    icon: "shoe.fill",
                    title: "Limited Drop",
                    color: .purple,
                    action: { selectedTaskType = .retail }
                )
                
                QuickActionButton(
                    icon: "airplane",
                    title: "Flight",
                    color: .blue,
                    action: { selectedTaskType = .flight }
                )
            }
        }
        .sheet(item: $selectedTaskType) { type in
            NewTaskView(initialType: type)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Tasks Section

struct RecentTasksSection: View {
    @EnvironmentObject var taskStore: TaskStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Tasks")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: TaskListView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }
            }
            .padding(.horizontal, 4)
            
            if taskStore.tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    Text("No tasks yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Create your first task above")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground))
                .cornerRadius(16)
            } else {
                ForEach(taskStore.tasks.prefix(3)) { task in
                    TaskRow(task: task)
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: AgentTask
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: task.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(.indigo)
                .frame(width: 44, height: 44)
                .background(Color.indigo.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.goal)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    StatusBadge(status: task.status)
                    
                    if let lastCheck = task.lastCheckAt {
                        Text("Checked \(timeAgo(from: lastCheck))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func timeAgo(from isoString: String) -> String {
        // Simplified - parse ISO date and format relative time
        return "recently"
    }
}

struct StatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        Text(status.statusDisplay)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForStatus(status).opacity(0.15))
            .foregroundStyle(colorForStatus(status))
            .cornerRadius(6)
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
}

// MARK: - Tips Section

struct TipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pro Tips")
                .font(.headline)
                .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(
                    icon: "clock.badge.checkmark",
                    title: "Check frequency",
                    description: "Faster checks use more tokens. Find your balance."
                )
                
                TipRow(
                    icon: "lock.shield",
                    title: "Store credentials",
                    description: "Save your info securely for faster checkout."
                )
                
                TipRow(
                    icon: "bell.badge",
                    title: "Enable notifications",
                    description: "Get notified the moment your task succeeds."
                )
            }
            .padding(16)
            .background(Color.indigo.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.indigo)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
