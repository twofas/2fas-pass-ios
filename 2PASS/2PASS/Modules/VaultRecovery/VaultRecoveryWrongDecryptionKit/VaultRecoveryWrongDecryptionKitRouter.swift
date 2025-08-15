// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct VaultRecoveryWrongDecryptionKitRouter {
    
    static func buildView(onSelectVault: @escaping Callback, onSelectDecryptionKit: @escaping Callback) -> some View {
        VaultRecoveryWrongDecryptionKitView(presenter: .init(onSelectVault: onSelectVault, onSelectDecryptionKit: onSelectDecryptionKit))
    }
}
