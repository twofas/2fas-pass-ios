// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct KnownBrowsersRouter: Router {

    @MainActor
    static func buildView() -> some View {
        KnownBrowsersView(presenter: .init(interactor: ModuleInteractorFactory.shared.knownBrowsersModuleInteractor()))
    }
    
    func routingType(for destination: KnownBrowsersDestination?) -> RoutingType? {
        switch destination {
        case .confirmDeletion:
            .alert(title: T.knownBrowserDeleteDialogTitle, message: T.knownBrowserDeleteDialogBody)
        default:
            nil
        }
    }
    
    func view(for destination: KnownBrowsersDestination) -> some View {
        switch destination {
        case .confirmDeletion(let onConfirm):
            Button(T.knownBrowserDeleteButton.localizedKey, role: .destructive, action: onConfirm)
            Button(T.commonCancel.localizedKey, role: .cancel, action: {})
        }
    }
}
