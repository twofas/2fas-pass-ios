// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public typealias RawItemData = _ItemData<Data>

extension RawItemData {
    
    public init(id: ItemID, vaultId: VaultID, metadata: ItemMetadata, name: String?, contentType: ItemContentType, contentVersion: Int, content: Content) {
        self.id = id
        self.vaultId = vaultId
        self.metadata = metadata
        self.name = name
        self.contentType = contentType
        self.contentVersion = contentVersion
        self.content = content
    }
    
    public init?(_ item: ItemData, encoder: JSONEncoder = .init()) {
        do {
            let contentData = try item.encodeContent(using: encoder)
            
            self = RawItemData(
                id: item.id,
                vaultId: item.vaultId,
                metadata: item.metadata,
                name: item.name,
                contentType: item.contentType,
                contentVersion: item.contentVersion,
                content: contentData
            )
        } catch {
            return nil
        }
    }
}

extension RawItemData {
    
    public func updateContent(_ contentData: Data, using newModificationDate: Date) -> RawItemData {
        .init(
            id: id,
            vaultId: vaultId,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: newModificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: trashedStatus,
                tagIds: tagIds
            ),
            name: name,
            contentType: contentType,
            contentVersion: contentVersion,
            content: contentData
        )
    }
}
