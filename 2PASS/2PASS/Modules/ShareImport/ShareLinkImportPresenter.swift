// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import Data

@Observable
final class ShareLinkImportPresenter {

    enum State {
        case loading
        case password
        case editor(any ItemDataChangeRequest)
        case error
    }

    private(set) var state: State = .loading

    var stateID: Int {
        switch state {
        case .loading: 0
        case .password: 1
        case .editor: 2
        case .error: 3
        }
    }
    
    var inputError: Bool {
        errorDescription.isEmpty == false
    }
    
    private(set) var errorDescription = ""
    var password = "" {
        didSet {
            if inputError { errorDescription = "" }
        }
    }
    private(set) var isDecrypting = false

    private let components: ShareLinkComponents
    private let interactor: ShareLinkImportModuleInteracting
    private let onDismiss: () -> Void
    private var fetchTask: Task<Void, Never>?
    private var encryptedData: String?

    var isPasswordEncrypted: Bool {
        switch components.encryption {
        case .password: true
        case .key: false
        }
    }

    init(
        components: ShareLinkComponents,
        interactor: ShareLinkImportModuleInteracting,
        onDismiss: @escaping () -> Void
    ) {
        self.components = components
        self.interactor = interactor
        self.onDismiss = onDismiss
    }

    func onAppear() {
        guard fetchTask == nil else { return }
        fetchTask = Task { @MainActor in
            do {
                let data = try await interactor.fetchSharedSecret(id: components.id)
                encryptedData = data

                if isPasswordEncrypted {
                    state = .password
                } else {
                    let result = try interactor.decryptSharedSecret(
                        encryptedData: data,
                        components: components,
                        password: nil
                    )
                    state = .editor(result)
                }
            } catch {
                Log("ShareLinkImportPresenter: Failed to fetch/decrypt: \(error)")
                state = .error
            }
        }
    }

    func onSubmitPassword() {
        guard let encryptedData, !password.isEmpty else { return }
        isDecrypting = true
        errorDescription = ""

        do {
            let result = try interactor.decryptSharedSecret(
                encryptedData: encryptedData,
                components: components,
                password: password
            )
            state = .editor(result)
        } catch {
            errorDescription = error.localizedDescription
        }

        isDecrypting = false
    }

    func onEditorClosed(_ result: SaveItemResult) {
        onDismiss()
    }

    func onDisappear() {
        fetchTask?.cancel()
        fetchTask = nil
    }
}
