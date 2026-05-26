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

    private(set) var isFetching: Bool = false

    var destination: VaultRecoveryS3Destination?

    /// Bucket required even for non-AWS endpoints (`x-amz-copy-source`); region only on AWS.
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

    /// `initialConfig` is reseeded on every successful Connect — only deviations from the
    /// most-recent baseline trigger the discard prompt.
    var hasUnsavedChanges: Bool {
        endpoint != (initialConfig?.endpoint.absoluteString ?? "")
            || region != (initialConfig?.region ?? "")
            || bucket != (initialConfig?.bucket ?? "")
            || accessKeyId != (initialConfig?.accessKeyId ?? "")
            || secretAccessKey != (initialConfig?.secretAccessKey ?? "")
            || allowTLSOff != (initialConfig?.allowTLSOff ?? false)
    }

    private let interactor: VaultRecoveryS3ModuleInteracting
    private let onSelect: (VaultRecoveryData) -> Void

    @ObservationIgnored
    private var fetchTask: Task<Void, Never>?

    /// Tracks the prior autofilled value so re-autofill never overwrites user-typed input.
    @ObservationIgnored
    private var lastAutofilledRegion: String?
    @ObservationIgnored
    private var lastAutofilledBucket: String?

    @ObservationIgnored
    private var initialConfig: S3ServiceConfig?

    init(
        interactor: VaultRecoveryS3ModuleInteracting,
        onSelect: @escaping (VaultRecoveryData) -> Void
    ) {
        self.interactor = interactor
        self.onSelect = onSelect

        if let config = interactor.cachedConfig {
            endpoint = config.endpoint.absoluteString
            region = config.region
            bucket = config.bucket
            accessKeyId = config.accessKeyId
            secretAccessKey = config.secretAccessKey
            allowTLSOff = config.allowTLSOff
            // Prime autofill memory so the `endpoint` didSet doesn't re-overwrite the
            // restored region/bucket on first load.
            lastAutofilledRegion = config.region
            lastAutofilledBucket = config.bucket
            // Baseline for `hasUnsavedChanges` — without this a verbatim-from-cache form
            // would register as "changed" on first open.
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

                // Cache is now the saved-state source of truth. `MainRepository` AES-GCM-
                // encrypts under the Secure-Enclave appKey internally; credentials never
                // travel through the view chain past this presenter.
                interactor.cacheConfig(config)
                // Re-baseline so the discard alert won't fire when back-navigating to a
                // form that matches the just-cached values verbatim.
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
                // Typed throws erase at the Task boundary; defensive fallback for future
                // additions to `VaultRecoveryS3Error`.
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
