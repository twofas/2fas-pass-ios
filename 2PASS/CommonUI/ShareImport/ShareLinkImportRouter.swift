// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data

public struct ShareLinkImportRouter {

    public static func buildView(
        components: ShareLinkComponents,
        onDismiss: @escaping () -> Void
    ) -> some View {
        ShareLinkImportView(
            presenter: ShareLinkImportPresenter(
                components: components,
                interactor: ModuleInteractorFactory.shared.shareLinkImportModuleInteractor(),
                onDismiss: onDismiss
            )
        )
    }
}
