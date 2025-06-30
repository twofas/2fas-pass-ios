// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct TrashRouter: Router {

    static func buildView() -> some View {
        TrashView(presenter: .init(interactor: ModuleInteractorFactory.shared.trashInteractor()))
    }
    
    func routingType(for destination: TrashDestination?) -> RoutingType? {
        switch destination {
        case .confirmDelete:
            .alert(title: T.trashDeleteConfirmTitleIos, message: T.trashDeleteConfirmBodyIos)
        case .upgradePlanPrompt:
            .sheet
        case nil:
            nil
        }
    }
    
    func view(for destination: TrashDestination) -> some View {
        switch destination {
        case .confirmDelete(_, let onFinish):
            Button(T.commonNo.localizedKey, role: .cancel) {
                onFinish(false)
            }
            Button(T.commonYes.localizedKey, role: .destructive) {
                onFinish(true)
            }
        case .upgradePlanPrompt(let limit):
            PremiumPromptRouter.buildView(
                title: Text(T.paywallNoticeItemsLimitRestoreTitle.localizedKey),
                description: Text(T.paywallNoticeItemsLimitRestoreMsg(limit).localizedKey)
            )
        }
    }
}
