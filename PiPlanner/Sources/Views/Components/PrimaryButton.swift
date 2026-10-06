import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    var showArrow: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .fontWeight(.semibold)
                if showArrow {
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isDisabled ? Theme.primaryNavy.opacity(0.5) : Theme.primaryNavy)
            .foregroundColor(.white)
            .cornerRadius(Theme.cornerRadius)
        }
        .disabled(isDisabled)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(Theme.primaryNavy)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Theme.primaryNavy.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct TextButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(Theme.primaryNavy)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Continue", action: {}, showArrow: true)
        PrimaryButton(title: "Disabled", action: {}, isDisabled: true)
        SecondaryButton(title: "Use a form", action: {})
        TextButton(title: "Skip", action: {})
    }
    .padding()
}
