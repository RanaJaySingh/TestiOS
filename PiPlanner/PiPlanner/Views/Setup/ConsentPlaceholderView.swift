import SwiftUI

/// Placeholder Consent destination (screen 3) until PIP-39.
struct ConsentPlaceholderView: View {
    var dedicatedAccountTitle: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Consent")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            if let dedicatedAccountTitle {
                Text("Dedicated: \(dedicatedAccountTitle)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Full Consent sheet arrives in PIP-39.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Consent")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            dedicatedAccountTitle.map { "Consent placeholder. Dedicated \($0)." }
                ?? "Consent placeholder."
        )
    }
}

#Preview {
    NavigationStack {
        ConsentPlaceholderView(dedicatedAccountTitle: "HDFC ••4821")
    }
}
