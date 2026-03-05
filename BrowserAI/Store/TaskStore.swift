//
//  TaskStore.swift
//  BrowserAI
//
//  Task management and creation
//

import Foundation
import Combine

@MainActor
class TaskStore: ObservableObject {
    @Published var tasks: [AgentTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadTasks(userId: String) async {
        isLoading = true
        
        do {
            tasks = try await APIService.shared.getTasks(userId: userId)
        } catch {
            errorMessage = "Failed to load tasks"
        }
        
        isLoading = false
    }
    
    func createTask(userId: String, type: TaskType, goal: String, frequency: Int, context: [String: Any]) async -> AgentTask? {
        isLoading = true
        
        do {
            let task = try await APIService.shared.createTask(
                userId: userId,
                type: type,
                goal: goal,
                frequency: frequency,
                context: context
            )
            tasks.insert(task, at: 0)
            return task
        } catch {
            errorMessage = "Failed to create task"
            return nil
        }
    }
    
    func getCostEstimate(userId: String, type: TaskType, frequency: Int, duration: Int) async -> CostEstimate? {
        do {
            return try await APIService.shared.estimateCost(
                userId: userId,
                taskType: type,
                frequency: frequency,
                duration: duration
            )
        } catch {
            print("Failed to get estimate: \(error)")
            return nil
        }
    }
    
    func getFrequencyOptions(userId: String, type: TaskType) async -> [FrequencyOption] {
        do {
            return try await APIService.shared.getFrequencyOptions(userId: userId, taskType: type)
        } catch {
            print("Failed to get options: \(error)")
            return []
        }
    }
    
    func activeTasksCount() -> Int {
        return tasks.filter { $0.status == .pending || $0.status == .monitoring || $0.status == .available }.count
    }
    
    func completedTasksCount() -> Int {
        return tasks.filter { $0.status == .completed }.count
    }
}
