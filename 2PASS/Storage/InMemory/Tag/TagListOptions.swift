// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public enum TagListOptions {
    case tag(ItemTagID)
    case all
    case tags([ItemTagID])
    case byName(String)
    case byVault(VaultID)
}

extension TagListOptions {
    var predicate: NSPredicate? {
        switch self {
        case .tag(let itemTagID): TagPredicate.findByItemTagID(itemTagID)
        case .all: nil
        case .tags(let list): TagPredicate.tagsIdentifiedByItemTagIDs(list)
        case .byName(let phrase): TagPredicate.findByName(phrase)
        case .byVault(let vaultID): TagPredicate.findByVaultID(vaultID)
        }
    }
    
    var sortDescriptors: [NSSortDescriptor]? {
        switch self {
        case .tag: nil
        case .all: [TagSortDescriptor.sortByNameAscending]
        case .tags: [TagSortDescriptor.position]
        case .byName: [TagSortDescriptor.sortByNameAscending]
        case .byVault: [TagSortDescriptor.position]
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

    static func tagsIdentifiedByItemTagIDs(_ itemTagIDs: [ItemTagID]) -> NSPredicate {
        NSPredicate(format: "tagID IN %@", itemTagIDs)
    }

    static func findByName(_ phrase: String) -> NSPredicate {
        NSPredicate(format: "name contains[c] %@", phrase)
    }

    static func findByVaultID(_ vaultID: VaultID) -> NSPredicate {
        NSPredicate(format: "vaultID == %@", vaultID as CVarArg)
    }
}
