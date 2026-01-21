// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct BulkTagsRouter: Router {

    static func buildView(presenter: BulkTagsPresenter) -> some View {
        BulkTagsSelectionView(presenter: presenter)
    }

    func view(for destination: BulkTagsDestination) -> some View {
        switch destination {
        case .addTag(let onClose):
            EditTagRouter.buildView(onClose: onClose)
        }
    }

    func routingType(for destination: BulkTagsDestination?) -> RoutingType? {
        switch destination {
        case .addTag:
            .sheet
        case nil:
            nil
        }
    }
}
