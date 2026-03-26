// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension PasskeyEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<PasskeyEntity> {
        NSFetchRequest<PasskeyEntity>(entityName: passkeyEntityName)
    }

    @NSManaged var credentialID: Data
    @NSManaged var rpID: String
    @NSManaged var username: String?
    @NSManaged var userHandle: Data
    @NSManaged var privateKey: Data
}
