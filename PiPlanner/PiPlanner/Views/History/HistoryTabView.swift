import SwiftUI

/// History tab stub — full list arrives in a later ticket (PIP History).
struct HistoryTabView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("History")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            Text("Opening balance and credit history will appear here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.tab")
    }
}

#Preview {
    NavigationStack {
        HistoryTabView()
    }
}
