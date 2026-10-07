import SwiftUI

/// Ask tab stub — Grok answers / proposals arrive in PIP-63.
struct AskTabView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Ask")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            Text("Ask PiPlanner about your goals. Full Ask tab arrives later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ask.tab")
    }
}

#Preview {
    NavigationStack {
        AskTabView()
    }
}
