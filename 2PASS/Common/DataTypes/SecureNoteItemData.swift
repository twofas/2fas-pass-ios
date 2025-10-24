public typealias SecureNoteItemData = _ItemData<SecureNoteContent>

public struct SecureNoteContent: ItemContent {
    
    public static let contentType: ItemContentType = .secureNote
    public static let contentVersion = 1
    
    public let name: String?
    public let text: Data?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case text = "s_text"
    }
    
    public init(name: String?, text: Data?) {
        self.name = name
        self.text = text
    }
}

extension ItemData {
    
    public var asSecureNote: SecureNoteItemData? {
        switch self {
        case .secureNote(let secureNoteItem): secureNoteItem
        default: nil
        }
    }
}
