// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

final class VaultRecoveryWrongDecryptionKitPresenter {
    
    let onSelectVault: Callback
    let onSelectDecryptionKit: Callback
    
    init(onSelectVault: @escaping Callback, onSelectDecryptionKit: @escaping Callback) {
        self.onSelectVault = onSelectVault
        self.onSelectDecryptionKit = onSelectDecryptionKit
    }
}
