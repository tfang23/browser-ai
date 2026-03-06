# Browser AI iOS

Production-ready iOS app for autonomous browser tasks. Terminal-style interface. Real StoreKit integration.

## Features

- **Terminal UI** — Dark theme, monospace font, authentic shell experience
- **Real-time Chat** — Streaming responses from browser-use + Kimi 2.5
- **In-App Purchases** — StoreKit 2 with server-side receipt validation
- **Push Notifications** — Alert when tasks complete
- **Secure Storage** — Keychain for credentials, tokens
- **Offline Queue** — Retry failed requests automatically

## Screenshots

| Terminal | Paywall | Welcome |
|----------|---------|---------|
| Dark terminal with $ prompt | Token packages | Onboarding |

## Architecture

```
┌─────────────────┐
│   TerminalView  │  SwiftUI terminal interface
│   (SwiftUI)     │
└────────┬────────┘
         │
┌────────▼────────┐
│ TerminalViewModel│  Business logic, state mgmt
│  (Observable)    │
└────────┬────────┘
         │
┌────────▼────────┐
│   APIService    │  URLSession, Codable
│    (async/await)│
└────────┬────────┘
         │
    HTTP/REST
         │
┌────────▼────────┐
│  Browser AI API │  FastAPI backend
│   (cloud/VPS)   │
└─────────────────┘
```

## Quick Start

```bash
# Clone
git clone https://github.com/tiantianfang/browser-ai.git
cd browser-ai/browser-ai-ios

# Build (requires Xcode 15+)
open Package.swift  # or create Xcode project

# Run
swift run  # or Cmd+R in Xcode
```

## Configuration

### 1. Backend URL

Edit `Services/APIService.swift`:

```swift
#if DEBUG
private let baseURL = "http://localhost:8000"  // Local dev
#else
private let baseURL = "https://api.browserai.com"  // Production
#endif
```

### 2. StoreKit Products

Configure in App Store Connect:
- `com.browserai.tokens.starter`
- `com.browserai.tokens.standard`
- `com.browserai.tokens.power`
- `com.browserai.tokens.enterprise`

Match product IDs in `StoreKitService.swift`.

### 3. Push Notifications

1. Enable Push in Signing & Capabilities
2. Upload APNS certificate to backend
3. Test with production build

## Key Files

| File | Purpose |
|------|---------|
| `BrowserAIApp.swift` | App entry, state management |
| `Views/TerminalView.swift` | Main terminal interface |
| `Views/ContentView.swift` | Root view, welcome screen |
| `Services/APIService.swift` | API client, networking |
| `Services/StoreKitService.swift` | IAP handling |
| `Models/Models.swift` | Data models |

## Terminal Design System

| Element | Color | Usage |
|---------|-------|-------|
| Background | #0d1117 | Terminal area |
| Header | #161b22 | Top bar |
| Prompt | #7ee787 | $ symbol |
| Input | #c9d1d9 | User text |
| Output | #c9d1d9 | Bot responses |
| Success | #7ee787 | Completed actions |
| Error | #f85149 | Failures |
| Warning | #ffa657 | Unavailable items |
| Dim | #8b949e | Secondary text |
| Accent | #58a6ff | Links, highlights |

Font: SF Mono (system monospaced)

## API Integration

### Chat Endpoint

```swift
let response = try await APIService.shared.sendMessage(
    userId: user.id,
    message: "Book French Laundry",
    sessionId: sessionId
)
```

Response includes:
- `response`: Text to display
- `state`: idle, asking_monitor, monitoring, etc.
- `actions`: Suggested buttons (y/n, frequencies, etc.)

### Token Balance

```swift
// Displayed in header
Text("\(appState.tokenBalance) tk")

// Updates automatically after purchase
appState.updateTokenBalance(newBalance)
```

## StoreKit Integration

### Purchase Flow

1. User taps token button
2. `PaywallView` presents products
3. User selects package
4. `StoreKitService.purchase()` initiates
5. Apple processes payment
6. Receipt sent to backend
7. Backend verifies with Apple
8. Tokens credited
9. UI updates

### Receipt Validation

Server-side verification required:

```swift
// In purchase():
if let receipt = transaction.jsonRepresentation {
    let user = try await APIService.shared.purchaseTokens(
        userId: userId,
        packageId: product.id,
        receipt: receipt.base64EncodedString()
    )
}
```

## State Management

```swift
@MainActor
class AppState: ObservableObject {
    @Published var user: User?
    @Published var tokenBalance: Int = 0
    @Published var isAuthenticated = false
}
```

- Persists to Keychain
- Restores on app launch
- Updates across all views

## Testing

```swift
// Mock API for UI tests
class MockAPIService: APIService {
    override func sendMessage(...) async throws -> ChatMessageResponse {
        return ChatMessageResponse(
            sessionId: "test",
            response: "Mock response",
            state: "idle"
        )
    }
}

// Inject in preview
ContentView()
    .environmentObject(AppState(mock: true))
```

## Production Checklist

- [ ] Backend deployed with HTTPS
- [ ] App Store products configured
- [ ] APNS certificates uploaded
- [ ] Privacy policy URL
- [ ] Terms of service URL
- [ ] Support email
- [ ] Screenshots for App Store
- [ ] App review notes prepared
- [ ] Beta testing via TestFlight
- [ ] Crash reporting (Sentry/Firebase)
- [ ] Analytics (Mixpanel/Amplitude)

## Distribution

### TestFlight (Internal)

```bash
# Archive in Xcode
# Distribute App → TestFlight
# Add internal testers
```

### App Store

```bash
# App Store Connect
# Prepare for Submission
# Fill metadata
# Submit for Review
```

## Support

- **Issues**: https://github.com/tfang23/browser-ai/issues
- **Email**: support@browserai.com

## License

MIT License - See LICENSE file
