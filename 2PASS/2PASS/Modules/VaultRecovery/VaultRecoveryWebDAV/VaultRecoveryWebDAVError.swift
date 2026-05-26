// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

enum VaultRecoveryWebDAVError: Error {
    case transport(BackupFileServiceError)
    case indexNotFound
    case vaultNotFound
    case indexIsDamaged
    case vaultIsDamaged
    case nothingToImport
    case schemaNotSupported(Int)
}
