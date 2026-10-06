import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryEntry.createdAt, order: .reverse) private var entries: [HistoryEntry]
    
    @State private var selectedEntry: HistoryEntry?
    @State private var filterType: HistoryEntry.EntryType?
    
    private var filteredEntries: [HistoryEntry] {
        if let filter = filterType {
            return entries.filter { $0.type == filter }
        }
        return entries
    }
    
    private var groupedEntries: [(String, [HistoryEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            entry.createdAt.dayMonthYearString
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterSection
                
                if entries.isEmpty {
                    emptyState
                } else if filteredEntries.isEmpty {
                    noMatchesState
                } else {
                    ForEach(groupedEntries, id: \.0) { date, dayEntries in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(dayEntries) { entry in
                                    HistoryRow(entry: entry) {
                                        selectedEntry = entry
                                    }
                                    
                                    if entry.id != dayEntries.last?.id {
                                        Divider()
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .padding(Theme.cardPadding)
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                        } header: {
                            Text(date)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 20)
        }
        .background(Theme.background)
        .navigationTitle("History")
        .sheet(item: $selectedEntry) { entry in
            HistoryDetailView(entry: entry)
                .presentationDetents([.medium, .large])
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: filterType == nil) {
                    filterType = nil
                }
                
                FilterChip(title: "Credits", isSelected: filterType == .newCredit) {
                    filterType = .newCredit
                }
                
                FilterChip(title: "Transfers", isSelected: filterType == .transfer) {
                    filterType = .transfer
                }
                
                FilterChip(title: "Withdrawals", isSelected: filterType == .withdrawal) {
                    filterType = .withdrawal
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundColor(Theme.primaryNavy.opacity(0.5))
            
            Text("No history yet")
                .font(.headline)
            
            Text("Your transactions will appear here")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    private var noMatchesState: some View {
        VStack(spacing: 16) {
            Text("No matching entries")
                .font(.headline)
            
            Button("Clear filter") {
                filterType = nil
            }
            .foregroundColor(Theme.primaryNavy)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.primaryNavy : Theme.cardBackground)
                .foregroundColor(isSelected ? .white : Theme.textPrimary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct HistoryDetailView: View {
    let entry: HistoryEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.primaryNavy.opacity(0.1))
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: entry.icon)
                                .font(.title)
                                .foregroundColor(Theme.primaryNavy)
                        }
                        
                        Text(entry.type.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(amountText)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(amountColor)
                        
                        Text(entry.createdAt.dayMonthYearString)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        if entry.isLocked {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                Text("Locked")
                                    .font(.caption)
                            }
                            .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    if !entry.splits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Split details")
                                .font(.headline)
                            
                            ForEach(entry.splits, id: \.goalId) { split in
                                HStack {
                                    Text(split.goalName)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(split.amount.formattedINR)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        if split.percent > 0 {
                                            Text("\(split.percent)%")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(Theme.cardPadding)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    
                    if let note = entry.note {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note")
                                .font(.headline)
                            
                            Text(note)
                                .font(.body)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.cardPadding)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                    }
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var amountText: String {
        switch entry.type {
        case .withdrawal:
            return "-\(entry.totalAmount.formattedINR)"
        default:
            return entry.totalAmount.formattedINR
        }
    }
    
    private var amountColor: Color {
        switch entry.type {
        case .withdrawal:
            return .red
        case .transfer:
            return Theme.primaryNavy
        default:
            return .green
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
