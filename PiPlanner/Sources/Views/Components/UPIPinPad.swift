import SwiftUI

struct UPIPinPad: View {
    let bankName: String
    let lastFourDigits: String
    let onComplete: (String) -> Void
    let onCancel: () -> Void
    
    @State private var pin: String = ""
    @State private var isProcessing: Bool = false
    
    private let pinLength = 4
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Check balance")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 4) {
                    Image(systemName: "building.columns")
                        .foregroundColor(Theme.primaryNavy)
                    Text("\(bankName) Bank ••\(lastFourDigits)")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            HStack(spacing: 12) {
                ForEach(0..<pinLength, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? Theme.primaryNavy : Theme.primaryNavy.opacity(0.2))
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.vertical, 20)
            
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 20) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            PinButton(text: "\(number)") {
                                addDigit("\(number)")
                            }
                        }
                    }
                }
                
                HStack(spacing: 20) {
                    PinButton(text: "⌫", isSystem: true) {
                        deleteDigit()
                    }
                    
                    PinButton(text: "0") {
                        addDigit("0")
                    }
                    
                    PinButton(text: "⏎", isSystem: true) {
                        if pin.count == pinLength {
                            submit()
                        }
                    }
                }
            }
            
            Button("Cancel") {
                onCancel()
            }
            .foregroundColor(Theme.primaryNavy)
            .padding(.top, 8)
        }
        .padding(24)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private func addDigit(_ digit: String) {
        guard pin.count < pinLength else { return }
        pin += digit
        
        if pin.count == pinLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                submit()
            }
        }
    }
    
    private func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }
    
    private func submit() {
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onComplete(pin)
            isProcessing = false
        }
    }
}

struct PinButton: View {
    let text: String
    var isSystem: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: isSystem ? 20 : 24, weight: .medium))
                .frame(width: 70, height: 70)
                .background(Theme.background)
                .foregroundColor(Theme.primaryNavy)
                .cornerRadius(35)
        }
    }
}

#Preview {
    UPIPinPad(
        bankName: "HDFC",
        lastFourDigits: "4821",
        onComplete: { pin in print("PIN: \(pin)") },
        onCancel: {}
    )
    .padding()
    .background(Theme.background)
}
