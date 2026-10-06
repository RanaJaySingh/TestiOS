import SwiftUI

/// Placeholder Goals tab (screen 9) until PIP-45. Navigation target after Opening split lock.
struct GoalsTabPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Goals")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            Text("Your opening balance is locked. Full Goals tab arrives in PIP-45.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goals tab placeholder. Opening balance locked.")
    }
}

#Preview {
    NavigationStack {
        GoalsTabPlaceholderView()
    }
}
