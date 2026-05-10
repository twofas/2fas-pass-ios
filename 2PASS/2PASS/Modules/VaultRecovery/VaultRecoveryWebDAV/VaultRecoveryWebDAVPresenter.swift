// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI
import Data
import Backup

enum VaultRecoveryWebDAVDestination: RouterDestination {
    case errorAlert(message: String)
    case selectVault(
        BackupIndex,
        baseURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        onSelect: (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void
    )

    var id: String {
        switch self {
        case .errorAlert: "errorAlert"
        case .selectVault: "selectVault"
        }
    }
}

@Observable @MainActor
final class VaultRecoveryWebDAVPresenter {

    var url: String = ""
    var allowTLSOff: Bool = false
    var username: String = ""
    var password: String = ""

    /// `true` while the index fetch is in flight. Drives the toolbar item's spinner and
    /// disabled state. A successful fetch is itself the connectivity check — there is no
    /// separate `testConnection` probe before it.
    private(set) var isFetching: Bool = false

    var destination: VaultRecoveryWebDAVDestination?

    /// Drives the toolbar Connect button's enabled state. Mirrors the backup form's
    /// add-mode predicate (no edit mode here — recovery has no original snapshot).
    var canSave: Bool {
        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard let normalized = interactor.normalizeURL(url) else {
            return false
        }
        guard interactor.isSecureURL(normalized) else {
            return false
        }
        return true
    }

    /// Drives the drag-dismiss "Unsaved changes" alert: any field non-empty / toggle on.
    var hasUnsavedChanges: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || allowTLSOff
            || !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !password.isEmpty
    }

    private let interactor: VaultRecoveryWebDAVModuleInteracting
    /// Bubbles the picked vault up to the parent presenter, which dismisses the WebDAV
    /// sheet and pushes the recovery flow into its own enclosing navigation stack —
    /// mirrors the iCloud source's pattern (`VaultRecoveryPresenter.onRestoreFromCloud`).
    private let onSelect: (VaultRecoveryData) -> Void

    /// Held so the in-flight fetch can be torn down on dismissal — without this the
    /// network request continues until the server responds even after the user backs out.
    @ObservationIgnored
    private var fetchTask: Task<Void, Never>?

    init(
        interactor: VaultRecoveryWebDAVModuleInteracting,
        onSelect: @escaping (VaultRecoveryData) -> Void
    ) {
        self.interactor = interactor
        self.onSelect = onSelect
    }

    func onSave() {
        guard !isFetching else { return }

        guard let normalizedURL = interactor.normalizeURL(url) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorWrongDirectoryUrl))
            return
        }
        guard interactor.isSecureURL(normalizedURL) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorIncorrectUrl))
            return
        }

        isFetching = true

        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let index = try await interactor.recover(
                    baseURL: url,
                    normalizedURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username.isEmpty ? nil : username,
                    password: password.isEmpty ? nil : password
                )
                isFetching = false
                fetchTask = nil
                if Task.isCancelled { return }
                destination = .selectVault(
                    index,
                    baseURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username,
                    password: password,
                    onSelect: { [weak self] vault, source in
                        // Hand the picked vault to the parent presenter, which dismisses
                        // the sheet and pushes the recovery flow into its own stack.
                        self?.onSelect(.file(vault, source: source))
                    }
                )
            } catch let error as VaultRecoveryWebDAVError {
                isFetching = false
                fetchTask = nil
                if Task.isCancelled { return }
                destination = .errorAlert(message: error.message)
            } catch {
                // Typed throws on a protocol erase to `any Error` at the Task boundary; the
                // catch above handles every realistic case, but a defensive fallback keeps
                // the UI responsive if a future change introduces a new error type.
                isFetching = false
                fetchTask = nil
                if Task.isCancelled { return }
                destination = .errorAlert(message: VaultRecoveryWebDAVError.transport(.invalidResponse).message)
            }
        }
    }

    func onDisappear() {
        fetchTask?.cancel()
    }
}
