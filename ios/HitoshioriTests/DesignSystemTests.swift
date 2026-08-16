import Testing
import UIKit

@testable import Hitoshiori

@MainActor
struct DesignSystemTests {
    @Test("カラーアセットをライト・ダークの両方で解決できる")
    func resolvesNamedColorsForEveryAppearance() {
        let bundle = Bundle(for: AppDelegate.self)
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)

        for name in ["AccentColor", "LaunchBackground", "SuccessColor", "DangerColor"] {
            #expect(UIColor(named: name, in: bundle, compatibleWith: nil) != nil)
            #expect(UIColor(named: name, in: bundle, compatibleWith: darkTrait) != nil)
        }
    }
}
