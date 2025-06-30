// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct ChangeSuccessRouter: Router {

    static func buildView(onFinish: @escaping Callback) -> some View {
        ChangeSuccessView(presenter: .init(onFinish: onFinish))
    }
    
    func view(for destination: ChangeSuccessDestination) -> some View {
        switch destination {
        case .vaultDecryptionKit(let onFinish):
            VaultDecryptionKitRouter.buildView(kind: .settings, onFinish: onFinish)
                .navigationBarBackButtonHidden()
        }
    }
    
    func routingType(for destination: ChangeSuccessDestination?) -> RoutingType? {
        .push
    }
}
