// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

@MainActor @Observable
final class SetupCompletePresenter {
    private(set) var interactor: SetupCompleteModuleInteracting
    
    init(interactor: SetupCompleteModuleInteracting) {
        self.interactor = interactor
    }
    
    func onFinish(using action: DismissFlowAction) {
        interactor.finish()
        action()
    }
}
