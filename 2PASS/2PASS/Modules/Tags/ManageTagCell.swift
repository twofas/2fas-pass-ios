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
                subtitle: Text(.tagDescription(String(tag.itemCount)))
            )
            
            Spacer()
            
            Menu {
                Button {
                    onEdit()
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text(.commonEdit)
                    }
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(.tagDeleteCta)
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
