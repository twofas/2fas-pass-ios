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

enum VaultRecoveryS3Destination: RouterDestination {
    case errorAlert(message: String)
    case loadFromCSV(onClose: (FileImportResult) -> Void)
    case selectVault(
        BackupIndex,
        config: S3ServiceConfig,
        onSelect: (ExchangeVaultVersioned) -> Void
    )

    var id: String {
        switch self {
        case .errorAlert: "errorAlert"
        case .loadFromCSV: "loadFromCSV"
        case .selectVault: "selectVault"
        }
    }
}

@Observable @MainActor
final class VaultRecoveryS3Presenter {

    var endpoint: String = "" {
        didSet { autofillFromAWSEndpoint() }
    }
    var region: String = ""
    var bucket: String = ""
    var accessKeyId: String = ""
    var secretAccessKey: String = ""
    var allowTLSOff = false

    /// `true` while the index fetch is in flight. Drives the toolbar item's spinner and
    /// disabled state. A successful fetch is itself the connectivity check — there is no
    /// separate `testConnection` probe before it.
    private(set) var isFetching: Bool = false

    var destination: VaultRecoveryS3Destination?

    /// Drives the toolbar Connect button's enabled state. Mirrors the settings form's
    /// add-mode predicate (no edit mode here — recovery has no original snapshot).
    /// Bucket is required even for non-AWS S3-compatible endpoints (the container's
    /// `finalizeVault` needs an explicit bucket name in `x-amz-copy-source`); region is
    /// only required when the endpoint targets AWS S3.
    var canSave: Bool {
        guard
            !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !secretAccessKey.isEmpty
        else {
            return false
        }
        let isAWSEndpoint = interactor.detect(endpoint: endpoint) != nil
        if isAWSEndpoint, region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        endpoint != (initialConfig?.endpoint.absoluteString ?? "")
            || region != (initialConfig?.region ?? "")
            || bucket != (initialConfig?.bucket ?? "")
            || accessKeyId != (initialConfig?.accessKeyId ?? "")
            || secretAccessKey != (initialConfig?.secretAccessKey ?? "")
            || allowTLSOff != (initialConfig?.allowTLSOff ?? false)
    }

    private let interactor: VaultRecoveryS3ModuleInteracting
    /// Bubbles the picked vault up to the parent presenter, which dismisses the S3
    /// sheet and pushes the recovery flow into its own enclosing navigation stack —
    /// mirrors the WebDAV source's pattern (`VaultRecoveryPresenter.onRestoreFromWebDAV`).
    private let onSelect: (VaultRecoveryData) -> Void

    /// Held so the in-flight fetch can be torn down on dismissal — without this the
    /// network request continues until the server responds even after the user backs out.
    @ObservationIgnored
    private var fetchTask: Task<Void, Never>?

    /// Last region/bucket values that autofill wrote into the form. When the user edits the
    /// endpoint, these let us tell "field still holds an autofilled value, safe to refresh"
    /// apart from "user typed something custom, leave it alone."
    @ObservationIgnored
    private var lastAutofilledRegion: String?
    @ObservationIgnored
    private var lastAutofilledBucket: String?

    // Snapshot of the "saved" config — captured at init (from the recovery cache, if any)
    // and refreshed on every successful Connect (after the cache write). Compared against
    // the live `@Observable` form fields by `hasUnsavedChanges` to gate the discard alert.
    @ObservationIgnored
    private var initialConfig: S3ServiceConfig?

    init(
        interactor: VaultRecoveryS3ModuleInteracting,
        onSelect: @escaping (VaultRecoveryData) -> Void
    ) {
        self.interactor = interactor
        self.onSelect = onSelect

        // Seed from the in-memory recovery cache on `MainRepository`. The cache handles
        // decryption and JSON decoding internally — `cachedConfig` returns the typed
        // `S3ServiceConfig?` directly. `nil` means "no cache" (or decode/decrypt failure);
        // defaults stand in that case.
        if let config = interactor.cachedConfig {
            endpoint = config.endpoint.absoluteString
            region = config.region
            bucket = config.bucket
            accessKeyId = config.accessKeyId
            secretAccessKey = config.secretAccessKey
            allowTLSOff = config.allowTLSOff
            // Prime autofill memory so a paste-then-restore sequence doesn't clobber the
            // restored region/bucket. Without this, the `endpoint`'s `didSet` re-runs
            // autofill against the empty-`lastAutofilled*` baseline and overwrites values
            // it shouldn't.
            lastAutofilledRegion = config.region
            lastAutofilledBucket = config.bucket
            // Capture the just-seeded config as the baseline for `hasUnsavedChanges`.
            // Without this the form would register as "changed" on first open even when
            // pre-filled verbatim from the recovery cache.
            initialConfig = config
        }
    }

    func onSave() {
        guard !isFetching else { return }

        guard let endpointURL = interactor.normalize(endpoint: endpoint) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorIncorrectUrl))
            return
        }

        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBucket = bucket.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccessKey = accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)

        let config = S3ServiceConfig(
            endpoint: endpointURL,
            region: trimmedRegion,
            bucket: trimmedBucket,
            accessKeyId: trimmedAccessKey,
            secretAccessKey: secretAccessKey,
            allowTLSOff: allowTLSOff
        )

        isFetching = true

        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let index = try await interactor.recover(config)
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
                interactor.cacheConfig(config)
                // The cache is now the source of truth for "saved" — re-baseline so the
                // discard alert won't fire if the user back-navigates from the vault list
                // to a form that exactly matches what was just cached.
                initialConfig = config

                destination = .selectVault(
                    index,
                    config: config,
                    onSelect: { [weak self] vault in
                        self?.onSelect(.file(vault, source: .s3))
                    }
                )
            } catch let error as VaultRecoveryS3Error {
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
                destination = .errorAlert(message: VaultRecoveryS3Error.transport(.invalidResponse).message)
            }
        }
    }

    func onLoadFromCSV() {
        destination = .loadFromCSV(onClose: { [weak self] result in
            self?.handleCSVImport(result)
        })
    }

    private func handleCSVImport(_ result: FileImportResult) {
        switch result {
        case .fileOpen(let url):
            do {
                let parsed = try interactor.parseAccessKeysCSV(at: url)
                accessKeyId = parsed.accessKeyId
                secretAccessKey = parsed.secretAccessKey
            } catch {
                destination = .errorAlert(message: String(localized: .s3CsvLoadFailed))
            }
        case .cantReadFile:
            destination = .errorAlert(message: String(localized: .s3CsvLoadFailed))
        case .cancelled:
            break
        }
    }

    /// Calls the interactor's pattern matcher and fills region/bucket from the URL when:
    /// (a) the field is empty, OR (b) the field still holds the value autofill last wrote
    /// — pasting a new AWS URL refreshes auto-derived values but never overwrites
    /// anything the user typed manually.
    private func autofillFromAWSEndpoint() {
        guard let detection = interactor.detect(endpoint: endpoint) else { return }
        if let detectedRegion = detection.region {
            let trimmed = region.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == lastAutofilledRegion {
                region = detectedRegion
                lastAutofilledRegion = detectedRegion
            }
        }
        if let detectedBucket = detection.bucket {
            let trimmed = bucket.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == lastAutofilledBucket {
                bucket = detectedBucket
                lastAutofilledBucket = detectedBucket
            }
        }
    }

    func onDisappear() {
        fetchTask?.cancel()
    }
}
