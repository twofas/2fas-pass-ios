import SwiftUI
import UIKit
import Common

public struct TagContentCell: View {

    let name: Text
    let color: ItemTagColor?
    let subtitle: Text?

    public init(name: Text, color: ItemTagColor?, subtitle: Text? = nil) {
        self.name = name
        self.color = color
        self.subtitle = subtitle
    }

    public var body: some View {
        if let color {
            Circle()
                .fill(Color(UIColor(color)))
                .frame(width: ItemTagColorMetrics.regular.size, height: ItemTagColorMetrics.regular.size)
        }

        VStack(alignment: .leading, spacing: 0) {
            name
                .foregroundStyle(.neutral950)
                .font(.bodyEmphasized)

            subtitle
                .foregroundStyle(.neutral500)
                .font(.footnote)
        }
    }
}
