// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ShareLinkImportPasswordRouter {

    static func buildView(
        onSubmit: @escaping (String) throws -> Void,
        onClose: @escaping () -> Void
    ) -> some View {
        ShareLinkImportPasswordView(
            presenter: ShareLinkImportPasswordPresenter(
                onSubmit: onSubmit,
                onClose: onClose
            )
        )
    }
}
