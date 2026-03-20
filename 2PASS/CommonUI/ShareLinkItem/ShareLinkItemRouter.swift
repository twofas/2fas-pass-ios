// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

@available(iOS 26.0, *)
struct ShareLinkItemRouter {
    static func buildView(itemID: ItemID) -> some View {
        NavigationStack {
            ShareLinkItemView(
                presenter: .init(
                    itemID: itemID,
                    interactor: ModuleInteractorFactory.shared.shareLinkItemModuleInteractor()
                )
            )
        }
    }
}
