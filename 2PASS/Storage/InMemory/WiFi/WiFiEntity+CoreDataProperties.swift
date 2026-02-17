// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension WiFiEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<WiFiEntity> {
        NSFetchRequest<WiFiEntity>(entityName: wifiEntityName)
    }

    @NSManaged var ssid: String?
    @NSManaged var password: Data?
    @NSManaged var notes: String?
    @NSManaged var securityType: String
    @NSManaged var hidden: Bool
}
