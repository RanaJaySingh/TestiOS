import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var currentSetupStep: SetupStep = .welcome
    @Published var selectedTab: MainTab = .goals
    @Published var showSettings: Bool = false
    @Published var pendingCredit: Decimal?
    @Published var isGrokAvailable: Bool = true
    
    enum SetupStep: Int, CaseIterable {
        case welcome = 1
        case accounts = 2
        case consent = 3
        case balanceAuto = 4
        case balanceManual = 5
        case upiPin = 6
        case goalChat = 7
        case goalForm = 8
        case inflation = 9
        case openingSplit = 10
        case complete = 11
    }
    
    enum MainTab: String, CaseIterable {
        case goals = "Goals"
        case history = "History"
        case ask = "Ask"
    }
    
    func advanceSetup() {
        if let nextStep = SetupStep(rawValue: currentSetupStep.rawValue + 1) {
            currentSetupStep = nextStep
        }
    }
    
    func goToSetupStep(_ step: SetupStep) {
        currentSetupStep = step
    }
}
