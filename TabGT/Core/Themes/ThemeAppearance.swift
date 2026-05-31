import SwiftUI

enum ThemeAppearance: String, Codable, Equatable {
    case dark
    case light

    var colorScheme: ColorScheme {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}
