import SwiftUI
import Common
import CommonUI

struct ManageTagCell: View {
    
    let tag: TagViewItem
    
    let onEdit: Callback
    let onDelete: Callback
    
    var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(tag.name)
                    .foregroundStyle(.neutral950)
                
                Text(T.tagDescription(tag.itemCount).localizedKey)
                    .foregroundStyle(.neutral500)
            }
            .font(.body)
            
            Spacer()
            
            Menu {
                Button {
                    onEdit()
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text(T.commonEdit.localizedKey)
                    }
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(T.tagDeleteCta.localizedKey)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
                    .frame(width: 40, height: 40, alignment: .trailing)
            }
            .tint(nil)
        }
    }
}
