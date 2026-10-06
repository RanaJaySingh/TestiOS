# PiPlanner

**Every Rupee Has a Plan.** — Indian savings-goal planner with AI assistant powered by Grok.

<img src="docs/screenshots/placeholder.png" alt="PiPlanner App" width="300" />

## Overview

PiPlanner helps users manage their savings goals by:
- Picking one **dedicated savings account** for goal tracking
- **Splitting every new credit** across goals by percentage
- **Locking saved amounts** so they can't be accidentally spent
- Providing an **AI assistant (Grok)** for goal parsing and questions

## Features

### Core Functionality
- 🎯 **Goal Management** - Create, edit, and track savings goals with inflation adjustment
- 💰 **Smart Split** - Automatically split incoming credits across goals by percentage
- 🔒 **Lock Mechanism** - History entries lock after saving to prevent modifications
- 📊 **Progress Tracking** - Visual progress indicators with On track/Behind status
- 🔄 **Balance Sync** - Demo UPI PIN pad for balance checking (no real integration)

### Journeys Implemented
- **J1: First-time Setup** - Welcome, account selection, consent, balance sync, goal creation, opening split
- **J2: New Amount Arrives** - Sync detection, credit assignment with standing or custom split
- **J3: Managing Goals** - Goal detail view, edit, delete with fund redistribution
- **J4: Transfer** - Move funds between goals with preview and confirmation
- **J5: Withdrawal** - Record balance decreases with proportional distribution
- **J6: History** - View all transactions with type filtering
- **J7: Settings** - Account management, sync preferences, demo reset
- **J8: Ask** - AI assistant for questions and actions

### Technical Features
- SwiftUI with iOS 17+
- SwiftData for local persistence
- Indian INR formatting (₹1,00,000)
- Deterministic stub Grok for demo
- Clean MVVM-ish architecture

## Requirements

- Xcode 15.0+
- iOS 17.0+
- macOS Sonoma 14.0+ (for development)

## Getting Started

### Opening the Project

1. Clone this repository
2. Open `PiPlanner.xcodeproj` in Xcode
3. Select a simulator (iPhone 15 Pro recommended)
4. Press `Cmd + R` to build and run

### Demo Profile

The app initializes with a demo profile:
- **User:** Rahul
- **Savings Account:** HDFC ••4821 with ₹1,00,000
- **Spending Account:** SBI ••7730 with ₹72,000
- **UPI PIN:** 1234 (for demo balance checks)

## Project Structure

```
PiPlanner/
├── Sources/
│   ├── App/
│   │   ├── PiPlannerApp.swift      # App entry point
│   │   └── ContentView.swift        # Root view with setup/main routing
│   │
│   ├── Models/
│   │   ├── Account.swift            # Bank account model
│   │   ├── Goal.swift               # Savings goal model
│   │   ├── HistoryEntry.swift       # Transaction history model
│   │   ├── UserSettings.swift       # User preferences model
│   │   └── AppState.swift           # App-wide state management
│   │
│   ├── Views/
│   │   ├── Setup/                   # First-time setup screens (J1)
│   │   │   ├── SetupFlowView.swift
│   │   │   ├── WelcomeScreen.swift
│   │   │   ├── AccountsScreen.swift
│   │   │   ├── ConsentScreen.swift
│   │   │   ├── BalanceAutoScreen.swift
│   │   │   ├── BalanceManualScreen.swift
│   │   │   ├── UPIPinScreen.swift
│   │   │   ├── GoalChatScreen.swift
│   │   │   ├── GoalFormScreen.swift
│   │   │   ├── InflationScreen.swift
│   │   │   └── OpeningSplitScreen.swift
│   │   │
│   │   ├── Main/
│   │   │   └── MainTabView.swift    # Tab bar navigation
│   │   │
│   │   ├── Goals/
│   │   │   ├── GoalsHomeView.swift  # Goals tab home (screen 9)
│   │   │   ├── GoalDetailView.swift # Goal detail screen
│   │   │   ├── TransferView.swift   # Transfer between goals (J4)
│   │   │   ├── SyncSheetView.swift  # Balance sync sheet
│   │   │   ├── WithdrawalView.swift # Withdrawal recording (J5)
│   │   │   └── AssignCreditView.swift # Credit assignment (J2)
│   │   │
│   │   ├── History/
│   │   │   └── HistoryView.swift    # History tab (J6)
│   │   │
│   │   ├── Ask/
│   │   │   └── AskView.swift        # Ask Grok tab (J8)
│   │   │
│   │   ├── Settings/
│   │   │   └── SettingsView.swift   # Settings sheet (J7)
│   │   │
│   │   └── Components/              # Reusable UI components
│   │       ├── PrimaryButton.swift
│   │       ├── AccountCard.swift
│   │       ├── GoalCard.swift
│   │       ├── BalanceCard.swift
│   │       ├── StepIndicator.swift
│   │       ├── PercentInput.swift
│   │       ├── UPIPinPad.swift
│   │       ├── HistoryRow.swift
│   │       ├── GrokProposalCard.swift
│   │       └── QuickActionButton.swift
│   │
│   ├── Services/
│   │   ├── GrokService.swift        # Stub Grok AI service
│   │   ├── DemoDataService.swift    # Demo data initialization
│   │   └── SplitEngine.swift        # Split calculation and validation
│   │
│   └── Utilities/
│       ├── Theme.swift              # Colors, typography, design tokens
│       ├── CurrencyFormatter.swift  # Indian INR formatting
│       └── DateFormatters.swift     # Date formatting utilities
│
├── Assets.xcassets/                 # App icons, colors
├── Preview Content/                 # Preview assets
└── Info.plist                       # App configuration
```

## Design System

### Colors
- **Primary Navy:** `rgb(0, 46, 110)` - Primary actions, selected states
- **Background:** `#F4F6FA` - App background
- **Cards:** White with subtle shadows
- **Status Green:** On track indicators
- **Status Amber:** Behind/warning indicators

### Typography
- Bold sans-serif for amounts
- System font with weight variations
- Large ₹ currency symbols

### Components
- iOS-style toggles
- Rounded cards with shadows
- Full-width primary buttons
- Step indicators with "Step X of 3" format

## Product Rules

1. **Exactly one dedicated savings account** - Only one account can be marked for goal tracking
2. **100% split required** - Credit percentages must total 100%
3. **Locked history** - Entries are immutable after saving
4. **Pending edits** - Goal changes apply at the next credit
5. **7% default inflation** - Target projections account for inflation

## Grok Integration

The app includes a stub Grok service that provides deterministic responses:

```swift
// Goal parsing keywords:
// "car" → Car goal (₹5,00,000, 24 months)
// "emergency" → Emergency fund (₹2,00,000, 12 months)
// "vacation" → Vacation (₹1,50,000, 18 months)
// etc.

// Ask responses:
// "transfer" → Suggests transfer action
// "new goal" → Suggests goal creation
// Other queries → Plain text responses
```

To wire up a real Grok API, update `GrokService.swift` to make actual API calls.

## Future Enhancements

- [ ] Real UPI/Paytm integration for balance sync
- [ ] Real Grok API integration
- [ ] Notifications for new credits
- [ ] Widget for goal progress
- [ ] iCloud sync across devices
- [ ] Export/import data

## License

This is a demo/prototype application.

---

Built with ❤️ for Indian savers
