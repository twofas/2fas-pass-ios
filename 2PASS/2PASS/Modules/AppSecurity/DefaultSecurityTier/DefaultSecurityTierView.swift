// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct DefaultSecurityTierView: View {
    
    @State
    var presenter: DefaultSecurityTierPresenter
    
    var body: some View {
        SettingsDetailsForm(T.settingsEntryProtectionLevel.localizedKey) {
            SecurityTierPickerView(selected: $presenter.selected)
        }
    }
}

#Preview {
    DefaultSecurityTierRouter.buildView()
}
