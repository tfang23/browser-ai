//
//  TerminalView.swift
//  BrowserAI
//
//  Main terminal interface - production ready
//

import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = TerminalViewModel()
    @State private var inputText = ""
    @State private var showPaywall = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            TerminalHeader(
                tokenBalance: appState.tokenBalance,
                onAddTokens: { showPaywall = true }
            )
            
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.lines) { line in
                            TerminalLineView(line: line) { action in
                                handleAction(action)
                            }
                            .id(line.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(red: 0.051, green: 0.067, blue: 0.086)) // #0d1117
                .onChange(of: viewModel.lines.count) { _ in
                    if let last = viewModel.lines.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            TerminalInputArea(
                text: $inputText,
                isDisabled: viewModel.isProcessing,
                onSubmit: sendMessage
            )
            .focused($isInputFocused)
        }
        .background(Color(red: 0.086, green: 0.106, blue: 0.133)) // #161b22
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(appState)
        }
        .onAppear {
            isInputFocused = true
            viewModel.setup(appState: appState)
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        Task {
            await viewModel.sendMessage(text)
        }
    }
    
    private func handleAction(_ action: String) {
        inputText = action
        sendMessage()
    }
}

// MARK: - Header

struct TerminalHeader: View {
    let tokenBalance: Int
    let onAddTokens: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text("browser-ai")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.345, green: 0.337, blue: 0.839)) // #5856d6
                
                Text("~")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color(red: 0.282, green: 0.310, blue: 0.345)) // #484f58
            }
            
            Spacer()
            
            Button(action: onAddTokens) {
                HStack(spacing: 4) {
                    Text("\(tokenBalance)")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.medium)
                    Text("tk")
                        .font(.system(.caption, design: .monospaced))
                    Text("+")
                        .font(.system(.subheadline, design: .monospaced))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tokenColor)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.086, green: 0.106, blue: 0.133))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(red: 0.188, green: 0.212, blue: 0.239)),
            alignment: .bottom
        )
    }
    
    private var tokenColor: Color {
        if tokenBalance < 50 {
            return Color(red: 0.855, green: 0.212, blue: 0.200) // danger
        } else if tokenBalance < 150 {
            return Color(red: 0.824, green: 0.600, blue: 0.129) // warning
        } else {
            return Color(red: 0.137, green: 0.525, blue: 0.212) // green
        }
    }
}

// MARK: - Line View

struct TerminalLineView: View {
    let line: TerminalLine
    let onAction: (String) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Timestamp
            Text(line.formattedTime)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(red: 0.431, green: 0.463, blue: 0.506))
                .frame(width: 50, alignment: .leading)
            
            // Content based on type
            switch line.type {
            case .welcome:
                Text(line.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color(red: 0.545, green: 0.580, blue: 0.619))
                
            case .input(let inputText):
                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color(red: 0.494, green: 0.906, blue: 0.529))
                    
                    Text(inputText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color(red: 0.788, green: 0.820, blue: 0.851))
                }
                
            case .output(let outputType):
                Text(line.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(colorForOutput(outputType))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
            case .actionButtons(let actions):
                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        Button(action.label) {
                            onAction(action.value)
                        }
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.188, green: 0.212, blue: 0.239))
                        .foregroundStyle(Color(red: 0.494, green: 0.906, blue: 0.529))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private func colorForOutput(_ type: TerminalLine.LineType.OutputType) -> Color {
        switch type {
        case .normal:
            return Color(red: 0.788, green: 0.820, blue: 0.851)
        case .success:
            return Color(red: 0.494, green: 0.906, blue: 0.529)
        case .error:
            return Color(red: 0.973, green: 0.318, blue: 0.188)
        case .warning:
            return Color(red: 1.0, green: 0.651, blue: 0.341)
        case .info:
            return Color(red: 0.345, green: 0.651, blue: 1.0)
        case .dim:
            return Color(red: 0.545, green: 0.580, blue: 0.619)
        }
    }
}

// MARK: - Input Area

struct TerminalInputArea: View {
    @Binding var text: String
    let isDisabled: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color(red: 0.494, green: 0.906, blue: 0.529))
            
            TextField("", text: $text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color(red: 0.788, green: 0.820, blue: 0.851))
                .placeholder(when: text.isEmpty) {
                    Text("book french laundry for 4...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color(red: 0.282, green: 0.310, blue: 0.345))
                }
                .disabled(isDisabled)
                .onSubmit(onSubmit)
            
            if isDisabled {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color(red: 0.545, green: 0.580, blue: 0.619))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.086, green: 0.106, blue: 0.133))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(red: 0.188, green: 0.212, blue: 0.239)),
            alignment: .top
        )
    }
}

// MARK: - View Model

@MainActor
class TerminalViewModel: ObservableObject {
    @Published var lines: [TerminalLine] = []
    @Published var isProcessing = false
    
    private var appState: AppState?
    private var sessionId: String?
    private let apiService = APIService.shared
    
    func setup(appState: AppState) {
        self.appState = appState
        
        // Add welcome message
        let welcomeText = """
            Long-horizon browser tasks:
              • Monitor prices, reservations, inventory
              • Execute when available
              • Pay only for what you use

            Type a task. Press return.
            """
        
        lines.append(TerminalLine(
            timestamp: Date(),
            content: welcomeText,
            type: .welcome
        ))
    }
    
    func sendMessage(_ text: String) async {
        guard let appState = appState, let user = appState.user else { return }
        
        isProcessing = true
        
        // Add input line
        lines.append(TerminalLine(
            timestamp: Date(),
            content: text,
            type: .input(text)
        ))
        
        // Add working indicator
        let workingLine = TerminalLine(
            timestamp: Date(),
            content: "→ checking... (come back later, this may take a moment)",
            type: .output(.dim)
        )
        lines.append(workingLine)
        
        do {
            let response = try await apiService.sendMessage(
                userId: user.id,
                message: text,
                sessionId: sessionId
            )
            
            // Remove working line
            lines.removeAll { $0.content.contains("checking...") }
            
            // Update session
            sessionId = response.sessionId
            
            // Determine output type from response state
            let outputType: TerminalLine.LineType.OutputType
            switch response.state {
            case "monitoring":
                outputType = .success
            case "asking_monitor":
                outputType = .warning
            case "error":
                outputType = .error
            default:
                outputType = .normal
            }
            
            // Add response line
            lines.append(TerminalLine(
                timestamp: Date(),
                content: response.response,
                type: .output(outputType)
            ))
            
            // Add action buttons if present
            if let actions = response.actions, !actions.isEmpty {
                lines.append(TerminalLine(
                    timestamp: Date(),
                    content: "",
                    type: .actionButtons(actions)
                ))
            }
            
            // Update token balance if needed
            if let result = response.result {
                // Could deduct tokens here based on result
            }
            
        } catch let error as APIError {
            lines.removeAll { $0.content.contains("checking...") }
            
            lines.append(TerminalLine(
                timestamp: Date(),
                content: "Error: \(error.localizedDescription)",
                type: .output(.error)
            ))
        } catch {
            lines.removeAll { $0.content.contains("checking...") }
            
            lines.append(TerminalLine(
                timestamp: Date(),
                content: "Unknown error occurred",
                type: .output(.error)
            ))
        }
        
        isProcessing = false
    }
}

// MARK: - Extensions

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
