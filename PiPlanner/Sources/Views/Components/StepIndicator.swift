import SwiftUI

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.background)
        .cornerRadius(12)
    }
}

struct PageDots: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Theme.primaryNavy : Theme.primaryNavy.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StepIndicator(currentStep: 1, totalSteps: 3)
        StepIndicator(currentStep: 2, totalSteps: 3)
        StepIndicator(currentStep: 3, totalSteps: 3)
        
        PageDots(currentPage: 0, totalPages: 4)
        PageDots(currentPage: 2, totalPages: 4)
    }
}
