// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension SecureNoteEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<SecureNoteEntity> {
        NSFetchRequest<SecureNoteEntity>(entityName: secureNoteEntityName)
    }

    @NSManaged var text: Data?
    @NSManaged var additionalInfo: String?
}