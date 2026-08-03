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
            .alert(title: String(localized: .trashDeleteConfirmTitleIos), message: String(localized: .trashDeleteConfirmBodyIos))
        case .confirmRemoveAll:
            .alert(title: String(localized: .trashRemoveAllConfirmTitle), message: String(localized: .trashRemoveAllConfirmBody))
        case .upgradePlanPrompt:
            .sheet
        case nil:
            nil
        }
    }
    
    func view(for destination: TrashDestination) -> some View {
        switch destination {
        case .confirmDelete(_, let onFinish):
            Button(.commonNo, role: .cancel) {
                onFinish(false)
            }
            Button(.commonYes, role: .destructive) {
                onFinish(true)
            }
        case .confirmRemoveAll(let onConfirm):
            Button(.trashRemoveAll, role: .destructive, action: onConfirm)
            Button(.commonCancel, role: .cancel, action: {})
        case .upgradePlanPrompt(let limit):
            PremiumPromptRouter.buildView(
                title: Text(.paywallNoticeItemsLimitRestoreTitle),
                description: Text(.paywallNoticeItemsLimitRestoreMsg(Int32(limit)))
            )
        }
    }
}
