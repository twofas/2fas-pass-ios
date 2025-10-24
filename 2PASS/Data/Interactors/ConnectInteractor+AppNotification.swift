// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CryptoKit

extension ConnectInteractor {

    // MARK: - App Notification Handling

    func validateNotification(_ notification: AppNotification) async -> Bool {
        guard let webBrowser = await webBrowser(for: notification) else {
            return false
        }

        guard let pkPersBe = Data(base64Encoded: notification.data.pkPersBe) else {
            return false
        }

        guard let sessionId = webBrowser.nextSessionID, let deviceId = mainRepository.deviceID else {
            return false
        }

        guard let pkEpheBe = Data(base64Encoded: notification.data.pkEpheBe) else {
            return false
        }
        let pkEpheBeHex = pkEpheBe.toHEXString()

        let inputString = "\(sessionId.toHEXString())\(deviceId)\(pkEpheBeHex)\(notification.data.timestamp)".lowercased()

        guard let data = inputString.data(using: .utf8) else {
            return false
        }

        let key = pkPersBe
        guard let signature = Data(base64Encoded: notification.data.sigPush) else {
            return false
        }

        do {
            let publicKey = try P256.Signing.PublicKey(compressedRepresentation: key)
            let signatureECDSA = try P256.Signing.ECDSASignature(rawRepresentation: signature)
            return publicKey.isValidSignature(signatureECDSA, for: data)
        } catch {
            Log("Notification has wrong signature", module: .connect, severity: .error)
            return false
        }
    }

    func connect(
        for notification: AppNotification,
        progress: @escaping (Float) -> Void,
        onReceiveBrowserInfo: @escaping (WebBrowser) -> Void,
        shouldPerfromAction: @escaping (ConnectAction) async -> ConnectContinuation
    ) async throws {
        guard let pkPersBe = Data(base64Encoded: notification.data.pkPersBe) else {
            throw ConnectError.badNotificationData
        }
        let pkPersBeHex = pkPersBe.toHEXString()

        guard let pkEpheBe = Data(base64Encoded: notification.data.pkEpheBe) else {
            throw ConnectError.badNotificationData
        }
        let pkEpheBeHex = pkEpheBe.toHEXString()

        guard let webBrowser = await webBrowsersInteractor.getWebBrowser(publicKey: pkPersBeHex) else {
            throw ConnectError.noWebBrowserForNotification
        }

        onReceiveBrowserInfo(webBrowser)

        guard let sessionId = webBrowser.nextSessionID?.toHEXString() else {
            throw ConnectError.missingSessionId
        }

        let schemeVersion: ConnectSchemaVersion = try {
            if let schemeString = notification.data.scheme {
                guard let schemeVersionInt = Int(schemeString), let schemeVersion = ConnectSchemaVersion(rawValue: schemeVersionInt) else {
                    throw ConnectError.unsupportedSchemeVersion
                }
                return schemeVersion
            } else {
                return .v1
            }
        }()

        let keys = try createKeys(pkEpheBeHex: pkEpheBeHex)

        let session = ConnectWebSocketSession(
            baseURL: Config.Connect.baseURL,
            sessionId: sessionId,
            deviceName: mainRepository.deviceName,
            appVersion: mainRepository.currentAppVersion
        )

        let continuationStorage = CheckedContinuationThreadSafeStorage<Void>()

        let connectingTask = Task {
            do {
                try await self.performPullConnecting(
                    using: session,
                    schemeVersion: schemeVersion,
                    keys: keys,
                    webBrowser: webBrowser,
                    progress: progress,
                    shouldPerfromAction: shouldPerfromAction
                )
                await continuationStorage.finish()
            } catch {
                await continuationStorage.finish(throwing: error)
            }
        }

        session.onClose {
            connectingTask.cancel()

            Task {
                await continuationStorage.finish(throwing: ConnectError.webSocketClosed)
            }
        }

        session.start()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    await continuationStorage.set(continuation)
                }
            }
        } onCancel: {
            connectingTask.cancel()
        }
    }

    @MainActor
    private func webBrowser(for notification: AppNotification) -> WebBrowser? {
        guard let pkPersBe = Data(base64Encoded: notification.data.pkPersBe) else {
            return nil
        }

        let pkPersBeHex = pkPersBe.toHEXString()

        return webBrowsersInteractor.getWebBrowser(publicKey: pkPersBeHex)
    }
}
