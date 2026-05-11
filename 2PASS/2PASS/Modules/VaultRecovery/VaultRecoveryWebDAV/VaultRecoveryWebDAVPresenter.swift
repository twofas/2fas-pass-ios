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
        onSelect: (ExchangeVaultVersioned) -> Void
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

    /// Drives the drag-dismiss "Unsaved changes" alert: form values differ from the
    /// last saved state. `initialConfig` is set at `init` (from the cache seed) and
    /// refreshed on a successful Connect (from the just-cached value) — so pre-filled-
    /// from-cache and just-cached states both register as "no unsaved changes." Only a
    /// *change* the user makes against the most-recent-saved baseline triggers the
    /// discard prompt. With no `initialConfig`, the baseline collapses to empty strings
    /// and `allowTLSOff = false` via optional-chain defaults — matching the "all-empty
    /// form is not 'unsaved'" semantics from before.
    var hasUnsavedChanges: Bool {
        url != (initialConfig?.baseURL ?? "")
            || allowTLSOff != (initialConfig?.allowTLSOff ?? false)
            || username != (initialConfig?.login ?? "")
            || password != (initialConfig?.password ?? "")
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

    // Snapshot of the "saved" config — captured at init (from the recovery cache, if any)
    // and refreshed on every successful Connect (after the cache write). Compared against
    // the live `@Observable` form fields by `hasUnsavedChanges` to gate the discard alert.
    @ObservationIgnored
    private var initialConfig: BackupWebDAVConfig?

    init(
        interactor: VaultRecoveryWebDAVModuleInteracting,
        onSelect: @escaping (VaultRecoveryData) -> Void
    ) {
        self.interactor = interactor
        self.onSelect = onSelect

        // Seed from the in-memory recovery cache on `MainRepository`. The cache handles
        // decryption and JSON decoding internally — `cachedConfig` returns the typed
        // `BackupWebDAVConfig?` directly. `nil` means "no cache" (or decode/decrypt
        // failure); defaults stand in that case.
        if let config = interactor.cachedConfig {
            url = config.baseURL
            allowTLSOff = config.allowTLSOff
            username = config.login ?? ""
            password = config.password ?? ""
            // `config.normalizedURL` is recomputed by `interactor.normalizeURL` on the next
            // `onSave`; `config.lockTime` is a backup-sync setting recovery has no opinion on
            // (the convenience init below uses `Config.webDAVLockFileTime`). Both ignored on
            // seed.
            //
            // Capture the just-seeded config as the baseline for `hasUnsavedChanges`.
            // Without this the form would register as "changed" on first open even when
            // pre-filled verbatim from the recovery cache.
            initialConfig = config
        }
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

                // Hand the validated config to the cache. `MainRepository` JSON-encodes
                // and AES-GCM-encrypts it under the Secure-Enclave appKey internally —
                // same pipeline `saveBackupConfigs` already uses on this type. The
                // strongly-typed value exists only across this call site; nothing about
                // the credentials travels through the view chain past this presenter.
                // The source enum bubbled upward is tag-only; `persistRecoverySource`
                // reads back from the cache when it commits to disk.
                let snapshot = BackupWebDAVConfig(
                    baseURL: url,
                    normalizedURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username.isEmpty ? nil : username,
                    password: password.isEmpty ? nil : password
                )
                interactor.cacheConfig(snapshot)
                // The cache is now the source of truth for "saved" — re-baseline so the
                // discard alert won't fire if the user back-navigates from the vault list
                // to a form that exactly matches what was just cached.
                initialConfig = snapshot

                destination = .selectVault(
                    index,
                    baseURL: normalizedURL,
                    allowTLSOff: allowTLSOff,
                    login: username,
                    password: password,
                    onSelect: { [weak self] vault in
                        self?.onSelect(.file(vault, source: .webDAV))
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
