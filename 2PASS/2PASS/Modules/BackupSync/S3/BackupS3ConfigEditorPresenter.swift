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

enum BackupS3ConfigEditorDestination: RouterDestination {
    case errorAlert(message: String)
    case loadSecretsFromCSV(onClose: (FileImportResult) -> Void)

    var id: String {
        switch self {
        case .errorAlert: "errorAlert"
        case .loadSecretsFromCSV: "loadSecretsFromCSV"
        }
    }
}

@Observable @MainActor
final class BackupS3ConfigEditorPresenter {

    var endpoint: String = "" {
        didSet { autofillFromAWSEndpoint() }
    }
    var region: String = ""
    var bucket: String = ""
    var accessKeyId: String = ""
    var secretAccessKey: String = ""
    var allowTLSOff = false

    private(set) var isTesting: Bool = false
    /// Counter (not Bool) so two consecutive successes still register as a value change
    /// and re-fire `.sensoryFeedback`.
    private(set) var successFeedbackTrigger: Int = 0
    private(set) var failureFeedbackTrigger: Int = 0
    /// Endpoint/bucket/access-key/secret all required. Bucket is required even for non-AWS
    /// endpoints because `CopyObject` needs an explicit bucket in `x-amz-copy-source`.
    /// Region is *additionally* required against `*.amazonaws.com` — SigV4 hashes it into
    /// the credential scope and a wrong region surfaces only as `SignatureDoesNotMatch`.
    /// In edit mode at least one field must differ from the loaded snapshot.
    var canSave: Bool {
        guard
            !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    var destination: BackupS3ConfigEditorDestination?

    let isEditMode: Bool

    private let interactor: BackupS3ConfigEditorModuleInteracting
    private let configID: BackupConfig.ID?
    /// Called on save (saved id) or programmatic close (`nil`). Toolbar Cancel uses
    /// `\.dismiss` directly and bypasses this.
    private let onClose: @MainActor (BackupConfig.ID?) -> Void
    @ObservationIgnored
    private var testTask: Task<Void, Never>?
    /// Distinguish "field still holds an autofilled value" from "user typed something
    /// custom" so re-autofill never clobbers manual input.
    @ObservationIgnored
    private var lastAutofilledRegion: String?
    @ObservationIgnored
    private var lastAutofilledBucket: String?
    /// Snapshot from form-open; drives per-field changed indicators in edit mode.
    @ObservationIgnored
    private var originalSnapshot: S3ServiceConfig?

    init(interactor: BackupS3ConfigEditorModuleInteracting, configID: BackupConfig.ID?, onClose: @escaping @MainActor (BackupConfig.ID?) -> Void) {
        self.interactor = interactor
        self.configID = configID
        self.onClose = onClose
        self.isEditMode = configID != nil
    }

    func onAppear() {
        if let existing = interactor.existingConfig {
            originalSnapshot = existing
            endpoint = existing.endpoint.absoluteString
            region = existing.region
            bucket = existing.bucket
            accessKeyId = existing.accessKeyId
            secretAccessKey = existing.secretAccessKey
            allowTLSOff = existing.allowTLSOff
        }
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

    /// Programmatic close without saving. Routes through `onClose` rather than
    /// `@Environment(\.dismiss)` so the close reaches whoever owns the host presentation
    /// (in add mode the form is nested inside the picker's NavigationStack, where a local
    /// dismiss would only pop back one level).
    func close() {
        onClose(nil)
    }

    func onSave() {
        guard !isTesting else { return }

        guard let endpointURL = interactor.normalize(endpoint: endpoint) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorIncorrectUrl))
            return
        }

        guard interactor.isSecureURL(endpointURL) else {
            destination = .errorAlert(message: String(localized: .syncStatusErrorIncorrectUrl))
            return
        }

        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBucket = bucket.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccessKey = accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecretKey = secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let config = S3ServiceConfig(
            endpoint: endpointURL,
            region: trimmedRegion,
            bucket: trimmedBucket,
            accessKeyId: trimmedAccessKey,
            secretAccessKey: trimmedSecretKey,
            allowTLSOff: allowTLSOff
        )

        isTesting = true

        testTask = Task { [weak self] in
            do {
                try await self?.interactor.testConnection(config)
                guard let self else { return }
                
                let savedID = interactor.save(config)
                isTesting = false
                testTask = nil
                onClose(savedID)
                
                // Delay so the haptic lands after the dismissal animation, not alongside it.
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
                // Delay so the haptic lands after the alert appears, not alongside it.
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                failureFeedbackTrigger &+= 1
            }
        }
    }

    func onDisappear() {
        testTask?.cancel()
    }

    func onLoadFromCSV() {
        destination = .loadSecretsFromCSV(onClose: { [weak self] result in
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

    /// Fills region/bucket from the URL when the field is empty or still holds the prior
    /// auto-derived value — never overwrites user-typed input.
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
