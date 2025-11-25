// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension CardEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<CardEntity> {
        NSFetchRequest<CardEntity>(entityName: cardEntityName)
    }

    @NSManaged var cardHolder: String?
    @NSManaged var cardNumber: Data?
    @NSManaged var expirationDate: Data?
    @NSManaged var securityCode: Data?
    @NSManaged var notes: String?
    @NSManaged var cardNumberMask: String?
    @NSManaged var cardIssuer: String?
}
