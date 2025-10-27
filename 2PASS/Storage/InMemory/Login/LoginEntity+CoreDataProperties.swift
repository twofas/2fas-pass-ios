// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common
import UIKit

extension LoginEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<LoginEntity> {
        NSFetchRequest<LoginEntity>(entityName: loginEntityName)
    }
    
    @NSManaged var username: String?
    @NSManaged var password: Data?
    @NSManaged var notes: String?
    @NSManaged var iconType: String
    @NSManaged var iconDomain: String?
    @NSManaged var iconURL: String?
    @NSManaged var iconLabelTitle: String?
    @NSManaged var iconColorHex: String?
    @NSManaged var uris: [String]?
    @NSManaged var urisMatching: [String]?
}
