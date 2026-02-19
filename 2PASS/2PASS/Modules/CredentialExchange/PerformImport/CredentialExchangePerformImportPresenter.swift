// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

@available(iOS 26.0, *)
enum CredentialExchangePerformImportState {
    case importing
    case success
}

@available(iOS 26.0, *)
@Observable @MainActor
final class CredentialExchangePerformImportPresenter {

    private(set) var state: CredentialExchangePerformImportState = .importing

    private let result: ExternalServiceImportResult
    private let interactor: CredentialExchangePerformImportModuleInteracting
    let onClose: Callback

    init(
        result: ExternalServiceImportResult,
        interactor: CredentialExchangePerformImportModuleInteracting,
        onClose: @escaping Callback
    ) {
        self.result = result
        self.interactor = interactor
        self.onClose = onClose
    }

    func onAppear() async {
        guard state == .importing else { return }
        await interactor.performImport(result)
        state = .success
    }
}
