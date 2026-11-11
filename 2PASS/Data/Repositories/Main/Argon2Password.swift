// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// The bytes Argon2 hashes for the master key. These cannot change without making every existing
/// vault unreadable, so `Argon2PasswordTests` pins them; the normalisation is NFKD, not NFD or NFC.
/// The returned buffer holds the password in the clear — the caller wipes it.
func argon2Password(seed: Data, masterPassword: String) -> Data {
    let normalized = Data(masterPassword.decomposedStringWithCompatibilityMapping.utf8)
    var input = Data(capacity: seed.count + normalized.count)
    input.append(seed)
    input.append(normalized)
    return input
}
