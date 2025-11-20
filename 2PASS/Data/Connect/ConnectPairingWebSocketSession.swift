// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CryptoKit

struct ConnectPairingWebSocketSession {
    
    let schemeVersion: ConnectSchemaVersion
    let webSocketSession: ConnectWebSocketSession

    func helloHandshake(deviceID: UUID, deviceName: String, deviceType: ConnectDeviceType) async throws -> ConnectRequests.Hello.ResponsePayload {
        let helloRequest = ConnectRequests.Hello(
            schemeVersion: schemeVersion,
            payload: .init(
                deviceId: deviceID.exportString(),
                deviceName: deviceName,
                deviceOs: "ios",
                deviceType: deviceType,
                supportedFeatures: schemeVersion < .v2 ? nil : []
            )
        )

        let helloResponse = try await webSocketSession.send(helloRequest)

        Log("Connect - Hello response received", module: .connect, severity: .info)

        return helloResponse
    }

    func challengeExchange(keys: ConnectInteractor.SessionKeys) async throws -> ConnectRequests.Challenge.ResponsePayload {
        let challengeRequest = ConnectRequests.Challenge(
            schemeVersion: schemeVersion,
            payload: .init(
                pkEpheMa: keys.publicKey.derRepresentation.base64EncodedString(),
                hkdfSalt: keys.hkdfSalt.base64EncodedString()
            )
        )

        let challengeResponse = try await webSocketSession.send(challengeRequest)

        Log("Connect - Challenge response received", module: .connect, severity: .info)

        return challengeResponse
    }


    func initTransfer(encryptedData: EncryptedTransferData) async throws {
        let dataToSend = encryptedData.gzipVaultsDataEnc.base64EncodedString()
        let chunkSize = Config.Connect.chunkSize
        let chunkCount = (dataToSend.count + chunkSize - 1) / chunkSize

        let initTransferRequest = ConnectRequests.InitTransfer(
            schemeVersion: schemeVersion,
            payload: .init(
                totalChunks: chunkCount,
                totalSize: encryptedData.gzipVaultsDataEnc.count,
                sha256GzipVaultDataEnc: Data(encryptedData.sha256Gzip).base64EncodedString(),
                fcmTokenEnc: encryptedData.fcmTokenEnc.base64EncodedString(),
                newSessionIdEnc: encryptedData.newSessionIdEnc.base64EncodedString(),
                expirationDateEnc: encryptedData.expirationDateEnc?.base64EncodedString()
            )
        )

        try await webSocketSession.send(initTransferRequest)

        Log("Connect - Init transfer response received", module: .connect, severity: .info)
    }

    func sendChunk(
        index: Int,
        chunkCount: Int,
        chunkSize: Int,
        dataToSend: String
    ) async throws {
        let startChunk = index * chunkSize
        let endChunk = min((index+1) * chunkSize, dataToSend.count)
        let chunkData = dataToSend[startChunk..<endChunk]

        if index == chunkCount - 1 {
            let transferRequest = ConnectRequests.TransferLastChunk(
                schemeVersion: schemeVersion,
                payload: .init(
                    chunkIndex: index,
                    chunkSize: chunkData.count,
                    chunkData: chunkData
                )
            )
            _ = try await webSocketSession.send(transferRequest)
        } else {
            let transferRequest = ConnectRequests.TransferChunk(
                schemeVersion: schemeVersion,
                payload: .init(
                    chunkIndex: index,
                    chunkSize: chunkData.count,
                    chunkData: chunkData
                )
            )
            _ = try await webSocketSession.send(transferRequest)
        }

        Log("Connect - Transfer chunk response received", module: .connect, severity: .info)
    }

    func closeConnectionWithSuccess() async throws {
        let closeRequest = ConnectRequests.CloseWithSuccess(schemeVersion: schemeVersion)
        try await webSocketSession.send(closeRequest)

        Log("Connect - Close with success response received", module: .connect, severity: .info)
    }

    func closeConnection(with error: Error) async {
        do {
            let closeWithError = ConnectRequests.CloseWithError(
                schemeVersion: schemeVersion,
                payload: .init(error: error)
            )
            try await webSocketSession.send(closeWithError)
        } catch {
            Log("Connect - Error while closing with error browser extension: \(error)", module: .connect)
        }

        Log("Connect - Error while connecting with browser extension: \(error)", module: .connect)
    }
}

extension ConnectPairingWebSocketSession {
    
    struct EncryptedTransferData {
        let newSessionIdEnc: Data
        let fcmTokenEnc: Data
        let gzipVaultsDataEnc: Data
        let expirationDateEnc: Data?
        let sha256Gzip: SHA256.Digest
    }
}
