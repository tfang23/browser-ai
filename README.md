# Browser AI iOS App

A clean, minimalist iOS app for the Browser AI agent service. Built with SwiftUI and StoreKit 2.

## Features

### Core Functionality
- **Token-based economy** — 300 free tokens for new users, buy more via Apple Pay
- **Create AI tasks** — Restaurants, tickets, retail drops, flights, hotels
- **Real-time cost estimation** — See token cost before committing
- **Persistent monitoring** — Agent checks periodically until successful
- **Secure credential storage** — Encrypted name, phone, payment info
- **Push notifications** — Alert when task succeeds

### Design
- **Clean, minimal interface** — Focus on content, not chrome
- **Indigo accent color** — Calm, professional
- **Native iOS patterns** — NavigationView, List, Form, Sheets
- **Dark mode support** — Automatic via system appearance

## Architecture

```
BrowserAI/
├── BrowserAIApp.swift       # App entry point, environment objects
├── Models/
│   └── Models.swift           # User, Task, TokenPackage, Credential
├── Views/
│   ├── WelcomeView.swift      # Onboarding / Sign up
│   ├── HomeView.swift         # Dashboard with balance, quick actions
│   ├── NewTaskView.swift      # Task creation with cost estimation
│   ├── TaskListView.swift     # All tasks with filters
│   ├── TokenShopView.swift    # Buy tokens (StoreKit integration)
│   └── ProfileView.swift      # Credentials, settings
├── Store/
│   ├── AuthService.swift      # User authentication state
│   ├── TokenStore.swift       # Token balance & purchases
│   └── TaskStore.swift        # Task CRUD operations
└── Services/
    ├── APIService.swift       # Backend API client
    └── StoreKitService.swift   # In-App Purchase handling
```

## Setup

### 1. Configure App Store Connect

1. Create app in App Store Connect
2. Configure In-App Purchases (auto-renewable subscriptions or consumables):
   - `com.browserai.tokens.starter` — 500 tokens + 100 bonus
   - `com.browserai.tokens.standard` — 1500 tokens + 300 bonus
   - `com.browserai.tokens.power` — 5000 tokens + 1000 bonus
   - `com.browserai.tokens.enterprise` — 20000 tokens + 5000 bonus

3. Set up Apple Pay merchant ID

### 2. Configure Xcode Project

1. Create new iOS project (iOS 16+)
2. Add files from this folder
3. Configure signing with your Apple ID
4. Add capabilities:
   - In-App Purchase
   - Push Notifications
   - Background Fetch (optional)

### 3. Configure Backend URL

In `Services/APIService.swift`:

```swift
private let baseURL = URL(string: "https://your-api-domain.com")!
```

### 4. Build & Run

```bash
# Open in Xcode
open BrowserAI.xcodeproj

# Or build from command line
xcodebuild -project BrowserAI.xcodeproj -scheme BrowserAI -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Key Screens

### WelcomeView
- Email/phone sign up
- 300 free tokens badge
- Clean gradient background

### HomeView
- **Token Balance Card** — Large balance display with "buy more" button
- **Quick Actions** — Grid of task types (restaurant, tickets, etc.)
- **Recent Tasks** — Last 3 tasks with status
- **Pro Tips** — Helpful hints for new users

### NewTaskView
1. Select task type
2. Enter goal (natural language)
3. Choose check frequency (5 min to 6 hours)
4. Set duration (1-30 days)
5. **Real-time cost estimate** — tokens & USD
6. Create task (validates sufficient balance)

### TokenShopView
- Current balance display
- 4 token packages with prices
- Apple Pay purchase sheet
- Restore purchases button

### TaskListView
- Filter: All / Active / Completed
- Pull to refresh
- Task detail with status, history, cost

### ProfileView
- Avatar with initials
- Token balance
- Saved credentials list
- Add credentials form
- Notification settings
- Sign out

## StoreKit Integration

The app uses StoreKit 2 for modern async/await-based in-app purchases:

```swift
// Purchase flow
let result = try await product.purchase()
switch result {
case .success(let verification):
    let transaction = try checkVerified(verification)
    // Send receipt to backend
    // Finish transaction
case .userCancelled:
    // Handle cancellation
case .pending:
    // Waiting for parental approval
}
```

## API Integration

The app expects a REST API matching the backend specification:

```
POST /users/                    # Create user (returns 300 free tokens)
GET  /users/{id}                # Get user profile
POST /users/{id}/estimate-tokens # Get cost estimate
POST /users/{id}/purchase-tokens # Verify Apple receipt, credit tokens
POST /tasks/persistent          # Create persistent monitoring task
GET  /users/{id}/tasks          # List user tasks
```

## Security Considerations

1. **Credentials** — Never stored locally, sent encrypted to backend
2. **Auth Token** — Stored in Keychain (not UserDefaults in production)
3. **Receipt Validation** — Backend validates Apple receipts with Apple
4. **HTTPS Only** — All API communication must be TLS 1.3+

## Customization

### Colors
Change accent color in `BrowserAIApp.swift`:
```swift
.tint(.indigo)  // Change to .blue, .purple, etc.
```

### Token Packages
Edit `TokenStore.swift` and App Store Connect to change packages.

### Task Types
Add to `TaskType` enum in `Models.swift`:
```swift
case carRental = "car_rental"
case visa = "visa_appointment"
```

## Production Checklist

- [ ] Replace API base URL with production domain
- [ ] Configure production App Store products
- [ ] Set up push notification certificates (APNs)
- [ ] Enable receipt validation on backend
- [ ] Add analytics (Firebase, Mixpanel, etc.)
- [ ] Crash reporting (Sentry, Crashlytics)
- [ ] Privacy policy & terms of service URLs
- [ ] App Store screenshots & description
- [ ] Test on real devices (not just simulator)

## License

This is a proof-of-concept. Use as starting point for production app.
