import SwiftUI
import UIKit

enum HitoshioriDesign {
    enum Palette {
        static let chipBackground = Color(uiColor: .secondarySystemFill)
        static let reminderBackground = Color(uiColor: .secondarySystemGroupedBackground)
        static let selectedChipText = Color.white
        static let success = Color("SuccessColor")
        static let danger = Color("DangerColor")
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum CornerRadius {
        static let card: CGFloat = 16
    }

    enum Typography {
        static let sectionTitle = Font.title3.weight(.semibold)
        static let metadata = Font.footnote
    }
}
