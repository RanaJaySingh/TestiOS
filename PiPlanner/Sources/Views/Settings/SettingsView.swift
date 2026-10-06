import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [UserSettings]
    @Query private var accounts: [Account]
    
    @State private var showResetConfirmation: Bool = false
    @State private var showConsentChange: Bool = false
    @State private var autoSync: Bool = true
    
    private var currentSettings: UserSettings? {
        settings.first
    }
    
    private var dedicatedAccount: Account? {
        accounts.first { $0.isDedicatedSavings }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(currentSettings?.userName ?? "Rahul")
                                .font(.headline)
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Theme.primaryNavy)
                                    .frame(width: 40, height: 40)
                                
                                Text(String((currentSettings?.userName ?? "R").prefix(1)))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                
                Section("Linked accounts") {
                    if let account = dedicatedAccount {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.shortDisplayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("Dedicated savings")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    ForEach(accounts.filter { !$0.isDedicatedSavings }) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.shortDisplayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(account.accountType.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                Section("Balance sync") {
                    Toggle(isOn: $autoSync) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Automatic balance updates")
                                .font(.subheadline)
                            
                            Text("Allow PiPlanner to check your balance")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.primaryNavy)
                    .onChange(of: autoSync) { _, newValue in
                        if let settings = currentSettings {
                            settings.hasConsentedToAutoSync = newValue
                            try? modelContext.save()
                        }
                    }
                }
                
                Section("Inflation") {
                    HStack {
                        Text("Default rate")
                        Spacer()
                        Text("\(Int((currentSettings?.defaultInflationRate ?? 0.07) * 100))%")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    HStack {
                        Text("Powered by")
                        Spacer()
                        Text("Grok")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Section {
                    Button(action: { showResetConfirmation = true }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset demo")
                        }
                        .foregroundColor(.red)
                    }
                } footer: {
                    Text("This will reset all data to the demo profile (Rahul with HDFC ₹1,00,000).")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                autoSync = currentSettings?.hasConsentedToAutoSync ?? true
            }
            .alert("Reset demo?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetDemo()
                }
            } message: {
                Text("This will delete all your data and restore the demo profile.")
            }
        }
    }
    
    private func resetDemo() {
        DemoDataService.shared.resetDemo(context: modelContext)
        dismiss()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
