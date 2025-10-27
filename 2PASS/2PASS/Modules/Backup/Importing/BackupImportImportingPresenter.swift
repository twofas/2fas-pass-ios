// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable
final class BackupImportImportingPresenter {
    private let interactor: BackupImportImportingModuleInteracting
    
    enum State {
        case importing
        case success
        case failure
    }

    private(set) var state: State = .importing
    
    let onClose: Callback
    
    init(interactor: BackupImportImportingModuleInteracting, onClose: @escaping Callback) {
        self.interactor = interactor
        self.onClose = onClose
    }
}

extension BackupImportImportingPresenter {
    
    func onAppear() {
        interactor.importItems { [weak self] result in
            switch result {
            case .success:
                self?.state = .success
            case .failure:
                self?.state = .failure
            }
        }
    }
}
