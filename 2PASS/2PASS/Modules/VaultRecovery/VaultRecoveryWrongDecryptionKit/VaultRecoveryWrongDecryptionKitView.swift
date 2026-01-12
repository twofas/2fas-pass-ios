// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryWrongDecryptionKitView: View {
    
    @State
    var presenter: VaultRecoveryWrongDecryptionKitPresenter
    
    var body: some View {
        ResultView(
            kind: .failure,
            title: Text(.vaultRecoveryWrongDecryptionKitTitle),
            description: Text(.vaultRecoveryWrongDecryptionKitDescription),
            action: {
                VStack {
                    Button(.vaultRecoveryWrongDecryptionKitAnotherDecryptionKitCta) {
                        presenter.onSelectDecryptionKit()
                    }
                    Button(.vaultRecoveryWrongDecryptionKitAnotherBackupCta) {
                        presenter.onSelectVault()
                    }
                    .buttonStyle(.twofasBorderless)
                }
            }
        )
    }
}

#Preview {
    VaultRecoveryWrongDecryptionKitView(presenter: .init(
        onSelectVault: {},
        onSelectDecryptionKit: {})
    )
}
