// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

/// Surfaces recovery-flow outcomes to the two recovery presenters
/// (`VaultRecoveryWebDAVPresenter`, `VaultRecoverySelectWebDAVIndexPresenter`).
///
/// `transport(_:)` wraps the new `BackupFileServiceError` for cases that originate inside the
/// HTTP/WebDAV transport (auth, TLS, server errors). The other cases describe outcomes the
/// transport cannot model on its own — JSON-decode failures, schema mismatch, or "did the
/// missing file mean the index or the vault is missing?" disambiguation. The two `*NotFound`
/// cases are produced by catching `BackupFileServiceError.notFound` per call site (index fetch
/// vs vault fetch) and re-throwing the appropriate variant, so the UI never sees
/// `transport(.notFound)`.
enum VaultRecoveryWebDAVError: Error {
    case transport(BackupFileServiceError)
    case indexNotFound
    case vaultNotFound
    case indexIsDamaged
    case vaultIsDamaged
    case nothingToImport
    case schemaNotSupported(Int)
}
