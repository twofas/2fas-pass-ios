// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Empty by design — the CloudKit container is fixed by build entitlements. Named struct
/// (not `Void`) so `BackupConfigEntry<Config>`'s Codable/Sendable constraints hold and the
/// on-disk JSON shape stays stable when fields are added.
public struct BackupiCloudConfig: Codable, Equatable, Sendable {
    public init() {}
}
