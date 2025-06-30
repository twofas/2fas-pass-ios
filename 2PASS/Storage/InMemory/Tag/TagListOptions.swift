// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public enum TagListOptions {
    case tag(ItemTagID)
    case all(VaultID)
    case tags([ItemTagID])
    case byName(String, VaultID)
}

extension TagListOptions {
    var predicate: NSPredicate {
        switch self {
        case .tag(let itemTagID): TagPredicate.findByItemTagID(itemTagID)
        case .all(let vaultID): TagPredicate.allTagsFromVault(vaultID)
        case .tags(let list): TagPredicate.tagsIdentifiedByItemTagIDs(list)
        case .byName(let phrase, let vaultID): TagPredicate.findByName(phrase, in: vaultID)
        }
    }
    
    var sortDescriptors: [NSSortDescriptor]? {
        switch self {
        case .tag: nil
        case .all: nil
        case .tags: [TagSortDescriptor.position]
        case .byName: [TagSortDescriptor.sortByNameAscending]
        }
    }
}


enum TagSortDescriptor {
    static let position = NSSortDescriptor(key: #keyPath(TagEntity.position), ascending: true)
    static let sortByNameAscending = NSSortDescriptor(
        key: #keyPath(TagEntity.name),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
    )
}

enum TagPredicate {
    static func findByItemTagID(_ itemTagID: ItemTagID) -> NSPredicate {
        NSPredicate(format: "tagID == %@", itemTagID as CVarArg)
    }
    
    static func allTagsFromVault(_ vaultID: VaultID) -> NSPredicate {
        NSPredicate(format: "vaultID == %@", vaultID as CVarArg)
    }
    
    static func tagsIdentifiedByItemTagIDs(_ itemTagIDs: [ItemTagID]) -> NSPredicate {
        NSPredicate(format: "tagID IN %@", itemTagIDs)
    }
    
    static func findByName(_ phrase: String, in vaultID: VaultID) -> NSPredicate {
        NSPredicate(format: "(name contains[c] %@) AND (vaultID == %@)", phrase, vaultID as CVarArg)
    }
}
