// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension PasswordListOptions {
    var predicate: NSPredicate? {
        var andPredicates: [NSPredicate] = []
        
        switch self {
        case .filterByPhrase(let phrase, _, let trashed):
            if let phrase, !phrase.isEmpty {
                andPredicates.append(Predicate.findByPhrase(phrase))
            }
            if let trashPredicate = trashed.predicate {
                andPredicates.append(trashPredicate)
            }
        case .findExistingByPasswordID(let passwordID):
            andPredicates.append(Predicate.findByPasswordID(passwordID))
        case .findNotTrashedByPasswordID(let passwordID):
            andPredicates.append(contentsOf: [Predicate.findByPasswordID(passwordID), Predicate.notTrashedItems])
        case .includePasswords(let passwordIDs):
            andPredicates.append(contentsOf: [Predicate.paswords(passwordIDs), Predicate.notTrashedItems])
        case .allTrashed:
            andPredicates.append(Predicate.trashedItems)
        case .allNotTrashed:
            andPredicates.append(Predicate.notTrashedItems)
        case .all:
            andPredicates.append(contentsOf: [])
        }
        
        if andPredicates.isEmpty {
            return nil
        }
        if andPredicates.count == 1 {
            return andPredicates.first
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }
    
    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .filterByPhrase(_, let sortBy, _):
            switch sortBy {
            case .az:
                return [PasswordSortDescriptor.sortByNameAscending, PasswordSortDescriptor.oldestFirst]
            case .za:
                return [PasswordSortDescriptor.sortByNameDescending, PasswordSortDescriptor.newestFirst]
            case .newestFirst:
                return [PasswordSortDescriptor.newestFirst, PasswordSortDescriptor.sortByNameDescending]
            case .oldestFirst:
                return [PasswordSortDescriptor.oldestFirst, PasswordSortDescriptor.sortByNameAscending]
            }
        case .allTrashed:
            return [PasswordSortDescriptor.trashingDate]
        default:
            return [PasswordSortDescriptor.newestFirst]
        }
    }
}

extension PasswordListOptions.TrashOptions {
    var predicate: NSPredicate? {
        switch self {
        case .yes:
            return Predicate.trashedItems
        case .no:
            return Predicate.notTrashedItems
        case .all:
            return nil
        }
    }
}

enum PasswordSortDescriptor {
    static let trashingDate = NSSortDescriptor(key: #keyPath(PasswordEntity.trashingDate), ascending: false)
    static let newestFirst = NSSortDescriptor(key: #keyPath(PasswordEntity.creationDate), ascending: false)
    static let oldestFirst = NSSortDescriptor(key: #keyPath(PasswordEntity.creationDate), ascending: true)
    static let sortByNameAscending = NSSortDescriptor(
        key: #keyPath(PasswordEntity.name),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
    )
    static let sortByNameDescending = NSSortDescriptor(
        key: #keyPath(PasswordEntity.name),
        ascending: false,
        selector: #selector(NSString.localizedStandardCompare)
    )
    static let sortByUsernameAscending = NSSortDescriptor(
        key: #keyPath(PasswordEntity.username),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare)
    )
    static let sortByUsernameDescending = NSSortDescriptor(
        key: #keyPath(PasswordEntity.username),
        ascending: false,
        selector: #selector(NSString.localizedStandardCompare)
    )
}

enum Predicate {
    static let trashedItems = NSPredicate(format: "isTrashed == TRUE")
    static let notTrashedItems = NSPredicate(format: "isTrashed == FALSE")
    
    static func findByPasswordID(_ passwordID: UUID) -> NSPredicate {
        NSPredicate(format: "passwordID == %@", passwordID as CVarArg)
    }
    
    static func paswords(_ passwordIDs: [UUID]) -> NSPredicate {
        NSPredicate(format: "passwordID IN %@", passwordIDs)
    }
    
    static func excludePasswords(_ passwordIDs: [UUID]) -> NSPredicate {
        NSPredicate(format: "NOT (passwordID IN %@)", passwordIDs)
    }
    
    static func findByPhrase(_ phrase: String) -> NSPredicate {
        NSPredicate(format: "(name contains[c] %@) OR (username contains[c] %@)", phrase, phrase)
    }
}
