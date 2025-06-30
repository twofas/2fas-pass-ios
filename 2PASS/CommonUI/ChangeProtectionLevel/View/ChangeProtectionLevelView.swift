// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ChangeProtectionLevelView: View {
    
    @Bindable
    var presenter: ChangeProtectionLevelPresenter
    
    var body: some View {
        Form {
            SecurityTierPickerView(selected: $presenter.currentProtectionLevel)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
