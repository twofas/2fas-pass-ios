// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

struct EncryptedStorageModelVersion: CoreDataModelVersionProtocol {
    let versionName: String
    let requiresReencryption: Bool

    init(_ versionName: String, requiresReencryption: Bool = false) {
        self.versionName = versionName
        self.requiresReencryption = requiresReencryption
    }
}
