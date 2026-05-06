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
    var id: String { "dismiss" }
}

@Observable @MainActor
final class BackupS3ConfigPresenter {

    var endpoint: String = ""
    var region: String = ""
    var bucket: String = ""
    var accessKeyId: String = ""
    var secretAccessKey: String = ""
    var allowTLSOff = false

    var validationError: String?
    /// Set when the connection probe fails. Distinct from `validationError` (synchronous field
    /// validation) because async probe failures arrive after the form has been validated.
    var connectionError: String?
    /// `true` while the probe is in flight. Drives the button's spinner and disabled state.
    private(set) var isTesting: Bool = false
    var destination: BackupS3ConfigDestination?

    let isEditMode: Bool

    private let interactor: BackupS3ConfigModuleInteracting
    private let configID: UUID?
    private let onClose: Callback

    init(interactor: BackupS3ConfigModuleInteracting, configID: UUID?, onClose: @escaping Callback) {
        self.interactor = interactor
        self.configID = configID
        self.onClose = onClose
        self.isEditMode = configID != nil
    }

    func onAppear() {
        guard let existing = interactor.existingConfig else { return }
        endpoint = existing.endpoint.absoluteString
        region = existing.region
        bucket = existing.bucket
        accessKeyId = existing.accessKeyId
        secretAccessKey = existing.secretAccessKey
        allowTLSOff = existing.allowTLSOff
    }

    func onSave() {
        guard !isTesting else { return }

        guard let endpointURL = URL(string: endpoint), endpointURL.scheme != nil else {
            validationError = String(localized: .syncStatusErrorIncorrectUrl)
            connectionError = nil
            return
        }

        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBucket = bucket.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccessKey = accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedRegion.isEmpty, !trimmedBucket.isEmpty, !trimmedAccessKey.isEmpty, !secretAccessKey.isEmpty else {
            validationError = String(localized: .s3MissingRequiredFields)
            connectionError = nil
            return
        }

        let config = S3ServiceConfig(
            endpoint: endpointURL,
            region: trimmedRegion,
            bucket: trimmedBucket,
            accessKeyId: trimmedAccessKey,
            secretAccessKey: secretAccessKey,
            allowTLSOff: allowTLSOff
        )

        validationError = nil
        connectionError = nil
        isTesting = true

        Task { [weak self] in
            do {
                try await self?.interactor.testConnection(config)
                guard let self else { return }
                if let configID {
                    interactor.saveUpdate(id: configID, with: config)
                } else {
                    interactor.saveAdd(config)
                }
                isTesting = false
                onClose()
            } catch {
                guard let self else { return }
                connectionError = BackupFileServiceError.connectionTestMessage(for: error)
                isTesting = false
            }
        }
    }
}
