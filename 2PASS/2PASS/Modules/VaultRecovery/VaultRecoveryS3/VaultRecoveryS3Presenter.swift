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
        onSelect: (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void
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

    /// Drives the drag-dismiss "Unsaved changes" alert: any field non-empty / toggle on.
    var hasUnsavedChanges: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !secretAccessKey.isEmpty
            || allowTLSOff
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

    init(
        interactor: VaultRecoveryS3ModuleInteracting,
        onSelect: @escaping (VaultRecoveryData) -> Void
    ) {
        self.interactor = interactor
        self.onSelect = onSelect
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
                destination = .selectVault(
                    index,
                    config: config,
                    onSelect: { [weak self] vault, source in
                        // Hand the picked vault to the parent presenter, which dismisses
                        // the sheet and pushes the recovery flow into its own stack.
                        self?.onSelect(.file(vault, source: source))
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
