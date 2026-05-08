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
    case connectionError(message: String)

    var id: String {
        switch self {
        case .dismiss: "dismiss"
        case .connectionError: "connectionError"
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

    var validationError: String?
    /// `true` while the probe is in flight. Drives the button's spinner and disabled state.
    private(set) var isTesting: Bool = false
    /// Drives the toolbar Save/Done button's enabled state. Endpoint, access key, and secret
    /// must all be filled in before tapping is allowed. Bucket is *additionally* required
    /// when the endpoint targets AWS S3 (`*.amazonaws.com`) — AWS signed requests need an
    /// explicit bucket; non-AWS S3-compatible providers may infer it from the URL or
    /// accept empty, so we surface a regular inline validation error there instead.
    /// In edit mode the button additionally requires at least one field to differ from the
    /// loaded values — re-saving an unchanged config would just trigger a redundant probe.
    var canSave: Bool {
        guard
            !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !secretAccessKey.isEmpty
        else {
            return false
        }
        let isAWSEndpoint = interactor.detect(endpoint: endpoint) != nil
        if isAWSEndpoint, bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if isEditMode, !hasUnsavedChanges {
            return false
        }
        return true
    }
    /// Surfaces the connection-test failure as an alert via the router; cleared automatically
    /// when the user dismisses the alert.
    var destination: BackupS3ConfigDestination?

    let isEditMode: Bool

    private let interactor: BackupS3ConfigModuleInteracting
    private let configID: UUID?
    private let onClose: Callback
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

    init(interactor: BackupS3ConfigModuleInteracting, configID: UUID?, onClose: @escaping Callback) {
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
        endpointChanged
            || regionChanged
            || bucketChanged
            || accessKeyIdChanged
            || secretAccessKeyChanged
            || allowTLSOffChanged
    }

    func onSave() {
        guard !isTesting else { return }

        guard let endpointURL = interactor.normalize(endpoint: endpoint) else {
            validationError = String(localized: .syncStatusErrorIncorrectUrl)
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

        validationError = nil
        isTesting = true

        testTask = Task { [weak self] in
            do {
                try await self?.interactor.testConnection(config)
                guard let self else { return }
                if let configID {
                    interactor.saveUpdate(id: configID, with: config)
                } else {
                    interactor.saveAdd(config)
                }
                isTesting = false
                testTask = nil
                onClose()
            } catch {
                guard let self else { return }
                isTesting = false
                testTask = nil
                if Task.isCancelled { return }
                destination = .connectionError(
                    message: BackupFileServiceError.connectionTestMessage(for: error)
                )
            }
        }
    }

    func cancelTest() {
        testTask?.cancel()
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
