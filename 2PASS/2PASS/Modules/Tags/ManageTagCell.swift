import SwiftUI
import Common

struct ManageTagCell: View {
    
    let tag: TagItem
    
    let onEdit: Callback
    let onDelete: Callback
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tag.name)
                    .foregroundStyle(.neutral950)
                
                Text("Items assigned: \(tag.itemCount)")
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
                        Text("Edit")
                    }
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove permanently")
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
