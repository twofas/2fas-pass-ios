// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupConfigsAddRouter: Router {

    var transitionNamespace: Namespace.ID?

    static let webDAVSourceID = "backupConfigs.add.webDAV"
    static let s3SourceID = "backupConfigs.add.s3"

    func routingType(for destination: BackupConfigsAddDestination?) -> RoutingType? {
        switch destination {
        case .webDAV, .s3:
            .push
        case nil:
            nil
        }
    }

    @ViewBuilder
    func view(for destination: BackupConfigsAddDestination) -> some View {
        switch destination {
        case .webDAV(let onClose):
            BackupWebDAVConfigRouter.buildView(configID: nil, onClose: onClose)
                .matchedZoomDestination(id: Self.webDAVSourceID, in: transitionNamespace)

        case .s3(let onClose):
            BackupS3ConfigRouter.buildView(configID: nil, onClose: onClose)
                .matchedZoomDestination(id: Self.s3SourceID, in: transitionNamespace)
        }
    }
}
