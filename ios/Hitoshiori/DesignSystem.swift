import SwiftUI
import UIKit

enum HitoshioriDesign {
    enum Color {
        static let accent = SwiftUI.Color("AccentColor")
        static let launchBackground = SwiftUI.Color("LaunchBackground")
        static let chipBackground = SwiftUI.Color(uiColor: .secondarySystemFill)
        static let reminderBackground = SwiftUI.Color(uiColor: .secondarySystemGroupedBackground)
        static let selectedChipText = SwiftUI.Color.white
        static let success = SwiftUI.Color.green
        static let danger = SwiftUI.Color.red
    }

    enum Spacing {
        static let xxSmall: CGFloat = 2
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let regular: CGFloat = 10
        static let large: CGFloat = 12
        static let xLarge: CGFloat = 16
    }

    enum CornerRadius {
        static let card: CGFloat = 16
    }

    enum Typography {
        static let sectionTitle = Font.title3.weight(.semibold)
        static let metadata = Font.footnote
    }
}
