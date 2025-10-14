// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable @MainActor
final class TransferItemsImportingPresenter {
    
    let onClose: Callback
    
    private(set) var state: State = .importing
    
    private let interactor: TransferItemsImportingModuleInteracting
    
    enum State {
        case importing
        case success
    }
    
    init(interactor: TransferItemsImportingModuleInteracting, onClose: @escaping Callback) {
        self.interactor = interactor
        self.onClose = onClose
    }
    
    func onAppear() async {
        state = .importing
        await interactor.importItems()
        state = .success
    }
}
