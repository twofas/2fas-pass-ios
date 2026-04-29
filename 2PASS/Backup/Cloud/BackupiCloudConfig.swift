// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// User-supplied configuration for an iCloud backup-sync entry.
///
/// Empty by design: the CloudKit container identifier is fixed by the build (Dev / Prod
/// entitlements) and reaches `CloudSync` through the existing `MainRepository` wiring.
/// Kept as a named struct rather than `Void` so that `BackupConfigEntry<Config>`'s
/// `Codable & Sendable` constraints are satisfied and future fields can be added without
/// changing the on-disk JSON shape.
public struct BackupiCloudConfig: Codable, Equatable, Sendable {
    public init() {}
}
