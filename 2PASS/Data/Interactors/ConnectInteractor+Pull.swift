// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CryptoKit

extension ConnectInteractor {
    
    func performPullConnecting(
        using webSocketSession: ConnectWebSocketSession,
        schemeVersion: ConnectSchemaVersion,
        keys: SessionKeys,
        webBrowser: WebBrowser,
        progress: (Float) -> Void,
        shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws {
            guard let deviceId = mainRepository.deviceID else {
                throw ConnectError.missingDeviceId
            }

            let pullSession = ConnectPullWebSocketSession(
                schemeVersion: schemeVersion,
                webSocketSession: webSocketSession
            )

            do {
                let helloResponse = try await pullSession.helloHandshake(
                    deviceID: deviceId,
                    deviceName: mainRepository.deviceName,
                    deviceType: .init(mainRepository.deviceType)
                )

                progress(0.25)

                let challengeResponse = try await pullSession.challengeExchange(keys: keys)

                progress(0.4)

                do {
                    try verifySalt(challengeResponse.hkdfSaltEnc, keys: keys)
                } catch {
                    throw ConnectError.saltVerificationFailed
                }

                guard let newSessionId = mainRepository.generateRandom(byteCount: Config.Connect.sessionIdByteCount),
                      let nonceS = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
                    throw ConnectError.encryptionFailure
                }


                let encryptionDataKey = deriveEncryptionDataKey(from: keys)

                guard let newSessionIdEnc = mainRepository.encrypt(newSessionId, key: encryptionDataKey, nonce: nonceS) else {
                    throw ConnectError.encryptionFailure
                }

                let pullResponse = try await pullSession.pull(newSessionIdEnc: newSessionIdEnc)

                progress(0.6)

                guard let decrypted = mainRepository.decrypt(pullResponse.dataEnc, key: encryptionDataKey) else {
                    throw ConnectError.decryptionFailure
                }

                var isCancelled = false
                let response: (any Encodable)?
                var isSync = false

                switch schemeVersion {
                case .v1:
                    let actionRequestType = try mainRepository.jsonDecoder.decode(ConnectSchemaV1.ConnectActioRequestType.self, from: decrypted)

                    do {
                        switch actionRequestType.type {
                        case .passwordRequest:
                            response = try await handlePasswordRequestResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                        case .newLogin:
                            response = try await handleNewLoginResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                        case .updateLogin:
                            response = try await handleUpdateLoginResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                        case .deleteLogin:
                            response = try await handleDeleteLoginResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                        }
                    } catch ConnectError.cancelled {
                        isCancelled = true
                        response = nil

                        try await sendPullActionCancelV1(
                            pullSession: pullSession,
                            actionType: actionRequestType.type,
                            encryptionDataKey: encryptionDataKey
                        )

                        Log("Connect - Pull action cancel sended", module: .connect, severity: .info)

                    } catch {
                        throw error
                    }

                case .v2:
                    let actionRequestType = try mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActioRequestType.self, from: decrypted)

                    do {
                        switch actionRequestType.type {
                        case .sifRequest:
                            response = try await handleSifResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                        case .addData:
                            response = try await handleAddData(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                        case .updateData:
                            response = try await handleUpdateData(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                        case .deleteData:
                            response = try await handleDeleteData(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                        case .fullSync:
                            try await handleSync(pullSession: pullSession, encryptionDataKey: encryptionDataKey, keys: keys, shouldPerfromAction: shouldPerfromAction)
                            response = nil
                            isSync = true
                        }
                    } catch ConnectError.cancelled {
                        isCancelled = true
                        response = nil

                        try await sendPullActionCancelV2(
                            pullSession: pullSession,
                            actionType: actionRequestType.type,
                            encryptionDataKey: encryptionDataKey
                        )

                        Log("Connect - Pull action cancel sended", module: .connect, severity: .info)
                    } catch {
                        throw error
                    }
                }

                try Task.checkCancellation()

                if let response {
                    let responseData = try mainRepository.jsonEncoder.encode(response)

                    guard let nonceD = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
                        throw ConnectError.encryptionFailure
                    }

                    guard let dateEnc = mainRepository.encrypt(responseData, key: encryptionDataKey, nonce: nonceD) else {
                        throw ConnectError.encryptionFailure
                    }

                    try await pullSession.sendPullActionResponse(dataEnc: dateEnc, isFullSync: isSync)
                }

                progress(0.9)

                await saveBrowser(webBrowser, helloResponse: helloResponse, newSessionId: newSessionId)

                try await pullSession.closeConnectionWithSuccess()

                progress(1.0)

                if isCancelled {
                    throw ConnectError.cancelled
                }

            } catch URLError.cancelled {
                throw ConnectError.cancelled
            } catch is CancellationError {
                throw ConnectError.cancelled
            } catch ConnectError.cancelled {
                throw ConnectError.cancelled
            } catch ConnectWebSocketError.webSocketClosed {
                throw ConnectError.webSocketClosed
            } catch {
                await pullSession.closeConnection(with: error)
                throw error
            }
    }

    func sendPullActionCancelV1(pullSession: ConnectPullWebSocketSession, actionType: ConnectSchemaV1.ConnectActionType, encryptionDataKey: SymmetricKey) async throws {
        guard let nonceD = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
            throw ConnectError.encryptionFailure
        }

        let actionData = ConnectSchemaV1.ConnectActionItemData(
            type: actionType,
            status: .cancel,
            login: nil
        )

        let jsonData = try mainRepository.jsonEncoder.encode(actionData)

        guard let dateEnc = mainRepository.encrypt(jsonData, key: encryptionDataKey, nonce: nonceD) else {
            return
        }

        try await pullSession.sendPullActionResponse(dataEnc: dateEnc)
    }

    func sendPullActionCancelV2(pullSession: ConnectPullWebSocketSession, actionType: ConnectSchemaV2.ConnectActionType, encryptionDataKey: SymmetricKey) async throws {
        guard let nonceD = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
            throw ConnectError.encryptionFailure
        }

        let actionData = ConnectSchemaV2.ConnectActionResponseData(
            type: actionType,
            status: .cancel
        )

        let jsonData = try mainRepository.jsonEncoder.encode(actionData)

        guard let dateEnc = mainRepository.encrypt(jsonData, key: encryptionDataKey, nonce: nonceD) else {
            return
        }

        try await pullSession.sendPullActionResponse(dataEnc: dateEnc)
    }
    
    private func saveBrowser(_ webBrowser: WebBrowser, helloResponse: ConnectRequests.Hello.ResponsePayload, newSessionId: Data) async {
        var webBrowser = webBrowser
        webBrowser.name = helloResponse.browserName
        webBrowser.version = helloResponse.browserVersion
        webBrowser.extName = helloResponse.browserExtName
        webBrowser.lastConnectionDate = mainRepository.currentDate
        webBrowser.nextSessionID = newSessionId
        await webBrowsersInteractor.update(webBrowser)
    }
}
