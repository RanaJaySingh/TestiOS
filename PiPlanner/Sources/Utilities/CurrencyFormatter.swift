import Foundation

struct CurrencyFormatter {
    static func formatINR(_ amount: Decimal, showSymbol: Bool = true) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let intValue = number.intValue
        let formatted = formatIndianNumber(intValue)
        return showSymbol ? "₹\(formatted)" : formatted
    }
    
    static func formatINR(_ amount: Int, showSymbol: Bool = true) -> String {
        let formatted = formatIndianNumber(amount)
        return showSymbol ? "₹\(formatted)" : formatted
    }
    
    private static func formatIndianNumber(_ number: Int) -> String {
        let isNegative = number < 0
        let absNumber = abs(number)
        let str = String(absNumber)
        
        if str.count <= 3 {
            return isNegative ? "-\(str)" : str
        }
        
        var result = ""
        let reversed = String(str.reversed())
        
        for (index, char) in reversed.enumerated() {
            if index == 3 {
                result.append(",")
            } else if index > 3 && (index - 3) % 2 == 0 {
                result.append(",")
            }
            result.append(char)
        }
        
        let formatted = String(result.reversed())
        return isNegative ? "-\(formatted)" : formatted
    }
    
    static func parseINR(_ string: String) -> Decimal? {
        let cleaned = string
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Decimal(string: cleaned)
    }
}

extension Decimal {
    var formattedINR: String {
        CurrencyFormatter.formatINR(self)
    }
}

extension Int {
    var formattedINR: String {
        CurrencyFormatter.formatINR(self)
    }
}
