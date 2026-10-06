import SwiftUI

enum Theme {
    static let primaryNavy = Color(red: 0, green: 46/255, blue: 110/255)
    static let background = Color(red: 244/255, green: 246/255, blue: 250/255)
    static let cardBackground = Color.white
    static let textPrimary = Color.black
    static let textSecondary = Color.gray
    static let textOnPrimary = Color.white
    
    static let statusGreen = Color.green
    static let statusAmber = Color.orange
    static let statusRed = Color.red
    
    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 20
    
    static let largeTitleSize: CGFloat = 28
    static let titleSize: CGFloat = 22
    static let headlineSize: CGFloat = 18
    static let bodySize: CGFloat = 16
    static let captionSize: CGFloat = 14
    static let smallSize: CGFloat = 12
}

extension Color {
    static let piPlannerNavy = Theme.primaryNavy
    static let piPlannerBackground = Theme.background
}

extension View {
    func cardStyle() -> some View {
        self
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    func primaryButtonStyle() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.primaryNavy)
            .foregroundColor(Theme.textOnPrimary)
            .cornerRadius(Theme.cornerRadius)
            .font(.headline)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .foregroundColor(Theme.primaryNavy)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(Theme.primaryNavy, lineWidth: 1)
            )
            .font(.headline)
    }
}
