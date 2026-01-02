import SwiftUI
import Common
import CommonUI

struct ManageTagCell: View {
    
    let tag: TagViewItem
    
    let onEdit: Callback
    let onDelete: Callback
    
    var body: some View {
        HStack(spacing: Spacing.m) {
            TagContentCell(
                name: Text(tag.name),
                color: tag.color,
                subtitle: Text(T.tagDescription(tag.itemCount).localizedKey)
            )
            
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
                    .foregroundStyle(.neutral500)
                    .frame(width: 40, height: 40, alignment: .trailing)
            }
            .tint(nil)
        }
    }
}
