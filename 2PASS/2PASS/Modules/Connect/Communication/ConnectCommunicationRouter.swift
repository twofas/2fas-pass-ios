// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Data
import Common

struct ConnectCommunicationRouter {
    
    @MainActor @ViewBuilder
    static func buildView(session: ConnectSession, onScanAgain: @escaping Callback) -> some View {
        ConnectCommunicationView(presenter: .init(
            session: session,
            interactor: ModuleInteractorFactory.shared.connectCommunicationInteractor(),
            onScanAgain: onScanAgain)
        )
    }
}
