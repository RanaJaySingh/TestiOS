// swift-tools-version: 5.9
import PackageDescription

/// Linux-friendly package for unit-testing models and services from Spec §3.1–3.5 / §4.1–4.2.
/// The iOS app target lives in PiPlanner.xcodeproj and shares the same source files.
let package = Package(
    name: "PiPlannerCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "PiPlannerCore", targets: ["PiPlannerCore"])
    ],
    targets: [
        .target(
            name: "PiPlannerCore",
            path: "PiPlanner",
            exclude: [
                "App",
                "Views",
                "ViewModels",
                "Components",
                "Resources",
                "Assets.xcassets",
                // SwiftUI theme wiring — Xcode app target only; tokens stay in DesignTokens.swift.
                "Theme/Color+DesignTokens.swift",
                "Theme/Theme.swift"
            ],
            sources: [
                "Models",
                "Services",
                "Theme"
            ]
        ),
        .testTarget(
            name: "PiPlannerCoreTests",
            dependencies: ["PiPlannerCore"],
            path: "PiPlannerTests",
            exclude: [
                // Xcode-host test scaffold + ViewModel tests (Combine / SwiftUI host).
                "PiPlannerTests.swift",
                "OpeningSplitViewModelTests.swift",
                "AccountsViewModelTests.swift",
                "WelcomeViewModelTests.swift",
                "ConsentViewModelTests.swift",
                "GoalChatViewModelTests.swift",
                "GoalsViewModelTests.swift",
                "StandingSplitViewModelTests.swift",
                "WithdrawalViewModelTests.swift",
                "TransferViewModelTests.swift",
                "SettingsViewModelTests.swift",
                "CreditUpdateBalanceViewModelTests.swift"
            ]
        )
    ]
)
