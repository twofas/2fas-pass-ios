// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

@Observable
final class ShareLinkImportPresenter {

    enum State {
        case loading
        case password
        case editor(any ItemDataChangeRequest)
        case error
        case networkError
    }

    private(set) var state: State = .loading

    var stateID: Int {
        switch state {
        case .loading: 0
        case .password: 1
        case .editor: 2
        case .error: 3
        case .networkError: 4
        }
    }

    private let components: ShareLinkComponents
    private let interactor: ShareLinkImportModuleInteracting
    private let onDismiss: () -> Void
    private var fetchTask: Task<Void, Never>?
    private var encryptedData: String?

    private var isPasswordEncrypted: Bool {
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
        fetchSharedData()
    }

    func decryptWithPassword(_ password: String) throws {
        guard let encryptedData else { return }

        let request = try interactor.decryptImportRequest(
            encryptedData: encryptedData,
            components: components,
            password: password
        )
        state = .editor(request)
    }

    func onRetry() {
        fetchTask?.cancel()
        fetchTask = nil
        state = .loading
        fetchSharedData()
    }

    func onClose() {
        onDismiss()
    }

    func onEditorClosed(_ result: SaveItemResult) {
        onDismiss()
    }

    func onDisappear() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    private func fetchSharedData() {
        guard fetchTask == nil else { return }
        fetchTask = Task { @MainActor in
            do {
                let data = try await interactor.fetchSharedSecret(id: components.id)
                encryptedData = data

                if isPasswordEncrypted {
                    state = .password
                } else {
                    let request = try interactor.decryptImportRequest(
                        encryptedData: data,
                        components: components,
                        password: nil
                    )
                    state = .editor(request)
                }
            } catch let httpError as HTTPError {
                Log("ShareLinkImportPresenter: HTTP error: \(httpError)")
                state = .error
            } catch {
                Log("ShareLinkImportPresenter: Network error: \(error)")
                state = .networkError
            }
        }
    }
}
