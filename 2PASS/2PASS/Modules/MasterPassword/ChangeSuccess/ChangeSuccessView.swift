// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct ChangeSuccessView: View {
    
    @State
    var presenter: ChangeSuccessPresenter
    
    var body: some View {
        ResultView(
            kind: .success,
            title: Text(T.setNewPasswordSuccessTitle.localizedKey),
            action: {
                Button(T.commonContinue.localizedKey, action: presenter.onContinue)
            }
        )
        .router(router: ChangeSuccessRouter(), destination: $presenter.destination)
    }
}
