import SwiftUI

enum ThemeHexColor {
    private static let shortHexPattern = /^#([0-9a-fA-F]{3})$/
    private static let longHexPattern = /^#([0-9a-fA-F]{6})$/
    private static let alphaHexPattern = /^#([0-9a-fA-F]{8})$/

    /// Parses `#RGB`, `#RRGGBB`, or `#RRGGBBAA` into a SwiftUI `Color`.
    static func color(from value: String) throws -> Color {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let match = trimmed.firstMatch(of: shortHexPattern) {
            let hex = String(match.1)
            let expanded = hex.map { String($0) + String($0) }.joined()
            return try color(fromSixDigitHex: expanded, alpha: 1)
        }

        if let match = trimmed.firstMatch(of: longHexPattern) {
            return try color(fromSixDigitHex: String(match.1), alpha: 1)
        }

        if let match = trimmed.firstMatch(of: alphaHexPattern) {
            let hex = String(match.1)
            let rgb = String(hex.prefix(6))
            let alphaHex = String(hex.suffix(2))
            guard let alphaByte = UInt8(alphaHex, radix: 16) else {
                throw ThemeImportError.invalidColor(key: "color", value: value)
            }
            let alpha = Double(alphaByte) / 255
            return try color(fromSixDigitHex: rgb, alpha: alpha)
        }

        throw ThemeImportError.invalidColor(key: "color", value: value)
    }

    /// Normalizes a color string to `#RRGGBB` or `#RRGGBBAA`.
    static func normalizedHex(from value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if let match = trimmed.firstMatch(of: shortHexPattern) {
            let hex = String(match.1)
            let expanded = hex.map { String($0) + String($0) }.joined()
            return "#\(expanded.uppercased())"
        }

        if let match = trimmed.firstMatch(of: longHexPattern) {
            return "#\(String(match.1).uppercased())"
        }

        if let match = trimmed.firstMatch(of: alphaHexPattern) {
            return "#\(String(match.1).uppercased())"
        }

        throw ThemeImportError.invalidColor(key: "color", value: value)
    }

    private static func color(fromSixDigitHex hex: String, alpha: Double) throws -> Color {
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            throw ThemeImportError.invalidColor(key: "color", value: "#\(hex)")
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Color {
    static func themeHex(_ hex: UInt32, opacity: Double = 1) -> Color {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        return Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
