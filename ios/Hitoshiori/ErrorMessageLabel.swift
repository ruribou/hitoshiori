import SwiftUI

struct ErrorMessageLabel: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(HitoshioriDesign.Typography.metadata)
            .foregroundStyle(HitoshioriDesign.Color.danger)
    }
}
