// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UniformTypeIdentifiers

extension [UTType] {
    public static var vaultFiles: [UTType] {
        [UTType(exportedAs: "com.twofas.org.TwoPASS.backup")]
    }
}
