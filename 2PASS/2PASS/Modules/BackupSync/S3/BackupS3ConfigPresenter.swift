// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import SwiftUI
import Backup
import Common
import CommonUI

enum BackupS3ConfigDestination: RouterDestination {
    case dismiss
    case errorAlert(message: String)
    case loadFromCSV(onClose: (FileImportResult) -> Void)

    var id: String {
        switch self {
        case .dismiss: "dismiss"
        case .errorAlert: "errorAlert"
        case .loadFromCSV: "loadFromCSV"
        }
    }
}

@Observable @MainActor
final class BackupS3ConfigPresenter {

    var endpoint: String = "" {
        didSet { autofillFromAWSEndpoint() }
    }
    var region: String = ""
    var bucket: String = ""
    var accessKeyId: String = ""
    var secretAccessKey: String = ""
    var allowTLSOff = false

    /// `true` while the probe is in flight. Drives the button's spinner and disabled state.
    private(set) var isTesting: Bool = false
    /// Bumped once each time the probe + save succeeds; the view observes this to fire a
    /// success haptic. Counter (not Bool) so two consecutive successes still register as
    /// distinct value changes and re-fire `.sensoryFeedback`.
    private(set) var successFeedbackTrigger: Int = 0
    /// Bumped once each time the probe fails (other than user cancellation); drives the
    /// error haptic. Same counter rationale as `successFeedbackTrigger`.
    private(set) var failureFeedbackTrigger: Int = 0
    /// Drives the toolbar Save/Done button's enabled state. Endpoint, bucket, access key,
    /// and secret must all be filled in before tapping is allowed. Bucket is required even
    /// for non-AWS S3-compatible endpoints: server-side `CopyObject` (used in `finalizeVault`)
    /// needs an explicit bucket name in the `x-amz-copy-source` header, and a virtual-hosted
    /// host like `bucket.example.com` does not satisfy that — the bucket has to be a string
    /// we can read back, not just whatever the user happened to encode in the URL.
    /// Region is *additionally* required when the endpoint targets AWS S3
    /// (`*.amazonaws.com`) — SigV4 hashes the region into the credential scope, so a wrong
    /// or empty region against AWS surfaces only as opaque `SignatureDoesNotMatch`. Non-AWS
    /// S3-compatible providers vary on whether they validate the region header, so we don't
    /// gate Save on it there.
    /// In edit mode the button additionally requires at least one field to differ from the
    /// loaded values — re-saving an unchanged config would just trigger a redundant probe.
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
        if isEditMode, !hasUnsavedChanges {
            return false
        }
        return true
    }
    var destination: BackupS3ConfigDestination?

    let isEditMode: Bool

    private let interactor: BackupS3ConfigModuleInteracting
    private let configID: UUID?
    /// Called on save (with the saved config's UUID) or programmatic close (with `nil`).
    /// Toolbar Cancel goes through `\.dismiss` directly and bypasses this callback.
    private let onClose: (UUID?) -> Void
    /// Held so the in-flight probe can be torn down on dismissal — without this the network
    /// request continues until the server responds even after the user taps Cancel.
    @ObservationIgnored
    private var testTask: Task<Void, Never>?
    /// Last region/bucket values that autofill wrote into the form. When the user edits the
    /// endpoint, these let us tell "field still holds an autofilled value, safe to refresh"
    /// apart from "user typed something custom, leave it alone."
    @ObservationIgnored
    private var lastAutofilledRegion: String?
    @ObservationIgnored
    private var lastAutofilledBucket: String?
    /// Snapshot of the config as it was when the form opened. Drives the per-field "changed"
    /// indicators that highlight modified rows in edit mode. Stays nil in add mode.
    @ObservationIgnored
    private var originalSnapshot: S3ServiceConfig?

    init(interactor: BackupS3ConfigModuleInteracting, configID: UUID?, onClose: @escaping (UUID?) -> Void) {
        self.interactor = interactor
        self.configID = configID
        self.onClose = onClose
        self.isEditMode = configID != nil
    }

    func onAppear() {
        guard let existing = interactor.existingConfig else { return }
        originalSnapshot = existing
        endpoint = existing.endpoint.absoluteString
        region = existing.region
        bucket = existing.bucket
        accessKeyId = existing.accessKeyId
        secretAccessKey = existing.secretAccessKey
        allowTLSOff = existing.allowTLSOff
    }

    var endpointChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return endpoint != original.endpoint.absoluteString
    }
    var regionChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return region != original.region
    }
    var bucketChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return bucket != original.bucket
    }
    var accessKeyIdChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return accessKeyId != original.accessKeyId
    }
    var secretAccessKeyChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return secretAccessKey != original.secretAccessKey
    }
    var allowTLSOffChanged: Bool {
        guard let original = originalSnapshot else { return false }
        return allowTLSOff != original.allowTLSOff
    }
    var hasUnsavedChanges: Bool {
        if isEditMode {
            return endpointChanged
                || regionChanged
                || bucketChanged
                || accessKeyIdChanged
                || secretAccessKeyChanged
                || allowTLSOffChanged
        }
        return !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !secretAccessKey.isEmpty
            || allowTLSOff
    }

    /// Programmatic close without saving. Used by the add-mode discard flow where the form
    /// is pushed inside the picker's `NavigationStack` — `@Environment(\.dismiss)` would
    /// only pop back to the picker, while routing through `onClose` reaches the captured
    /// sheet-root dismiss and tears down the entire sheet.
    func cancelAndClose() {
        onClose(nil)
    }

    func onSave() {
        guard !isTesting else { return }

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

        isTesting = true

        testTask = Task { [weak self] in
            do {
                try await self?.interactor.testConnection(config)
                guard let self else { return }
                let savedID: UUID
                if let configID {
                    interactor.saveUpdate(id: configID, with: config)
                    savedID = configID
                } else {
                    savedID = interactor.saveAdd(config)
                }
                isTesting = false
                testTask = nil
                onClose(savedID)
                // Brief delay so the success haptic punctuates the dismissal
                // animation instead of firing alongside it.
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }
                successFeedbackTrigger &+= 1
            } catch {
                guard let self else { return }
                isTesting = false
                testTask = nil
                if Task.isCancelled { return }
                destination = .errorAlert(
                    message: BackupFileServiceError.connectionTestMessage(for: error)
                )
                // Brief delay so the error haptic punctuates the alert's presentation
                // animation instead of firing alongside it.
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                failureFeedbackTrigger &+= 1
            }
        }
    }

    func cancelTest() {
        testTask?.cancel()
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
}
