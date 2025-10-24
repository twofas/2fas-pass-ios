// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CoreData

extension RawEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<RawEntity> {
        NSFetchRequest<RawEntity>(entityName: entityName)
    }
    
    @NSManaged var content: Data
}
