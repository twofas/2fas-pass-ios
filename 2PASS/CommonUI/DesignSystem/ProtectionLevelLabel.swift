import SwiftUI
import Common

struct ProtectionLevelLabel: View {
    
    let level: ItemProtectionLevel
    
    init(_ level: ItemProtectionLevel) {
        self.level = level
    }
    
    var body: some View {
        Label {
            Text(level.title)
        } icon: {
            level.icon
                .renderingMode(.template)
                .foregroundStyle(.accent)
        }
        .labelStyle(.rowValue)
    }
}
