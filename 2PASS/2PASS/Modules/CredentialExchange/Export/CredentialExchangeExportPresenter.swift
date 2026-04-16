// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CommonUI
import AuthenticationServices

@available(iOS 26.0, *)
enum CredentialExchangeExportDestination: RouterDestination {
    case error(onClose: Callback)

    var id: String {
        switch self {
        case .error: "error"
        }
    }
}

@available(iOS 26.0, *)
@Observable @MainActor
final class CredentialExchangeExportPresenter {

    enum ExportError: Error {
        case noWindow
    }

    enum State {
        case idle
        case exporting
    }

    private(set) var state: State = .idle
    var destination: CredentialExchangeExportDestination?

    var selectedVaultID: VaultID?
    let availableVaults: [VaultData]

    var hasMultipleVaults: Bool {
        availableVaults.count > 1
    }

    private let interactor: CredentialExchangeExportModuleInteracting
    private let onClose: Callback

    init(
        interactor: CredentialExchangeExportModuleInteracting,
        onClose: @escaping Callback
    ) {
        self.interactor = interactor
        self.onClose = onClose

        let nonEmptyVaults = interactor.listVaults().filter { !$0.isEmpty }
        self.availableVaults = nonEmptyVaults

        let defaultVaultID = interactor.defaultVaultID ?? nonEmptyVaults.first?.vaultID
        self.selectedVaultID = defaultVaultID.flatMap { id in
            nonEmptyVaults.contains(where: { $0.vaultID == id }) ? id : nil
        }
    }

    func startExport() {
        guard let selectedVaultID else { return }
        guard case .idle = state else { return }
        
        state = .exporting
        Task { @MainActor in
            do {
                guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap(\.windows)
                    .first(where: \.isKeyWindow)
                else {
                    throw ExportError.noWindow
                }
                
                try await interactor.performExport(vaultID: selectedVaultID, anchor: window)
                onClose()
            } catch let error as NSError
                where error.domain == "com.apple.AuthenticationServicesCore.AuthorizationError" && error.code == 2 {
                state = .idle
            } catch {
                state = .idle
                destination = .error(onClose: { [weak self] in
                    self?.onClose()
                })
            }
        }
    }
}
