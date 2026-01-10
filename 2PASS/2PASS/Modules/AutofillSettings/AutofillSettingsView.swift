// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct AutofillSettingsView: View {
    
    @State
    var presenter: AutofillSettingsPresenter
        
    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(.settingsEntryAutofill) {
                Section {
                    Toggle(.settingsAutofillService, isOn: $presenter.isEnabled)
                        .tint(.accentColor)
                } footer: {
                    Text(.settingsAutofillServiceDescription)
                        .settingsFooter()
                }
            }
            
            SettingsSystemLinkButton(
                description: Text(.settingsAutofillOpenSystemSettingsDescription),
                action: {
                    presenter.onSystemSettings()
                }
            )
            .padding(.vertical, Spacing.xl)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .task {
            await presenter.observeAutoFillStatusChanged()
        }
    }
}

#Preview {
    AutofillSettingsRouter.buildView()
}
