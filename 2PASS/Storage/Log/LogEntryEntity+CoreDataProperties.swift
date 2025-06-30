// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData

extension LogEntryEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<LogEntryEntity> {
        NSFetchRequest<LogEntryEntity>(entityName: "LogEntryEntity")
    }

    @NSManaged var timestamp: Date
    @NSManaged var content: String
    @NSManaged var module: Int16
    @NSManaged var severity: Int16
}

extension LogEntryEntity: Identifiable {}
