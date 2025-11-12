// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

struct ConnectPullWebSocketSession {
    
    let schemeVersion: ConnectSchemaVersion
    let webSocketSession: ConnectWebSocketSession

    // MARK: - Hello Handshake

    func helloHandshake(deviceID: UUID, deviceName: String, deviceType: ConnectDeviceType) async throws -> ConnectRequests.Hello.ResponsePayload {
        let helloRequest = ConnectRequests.Hello(
            schemeVersion: schemeVersion,
            payload: .init(
                deviceId: deviceID.uuidString,
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

    // MARK: - Challenge Exchange

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

    // MARK: - Pull Request

    func pull(newSessionIdEnc: Data) async throws -> ConnectRequests.Pull.ResponsePayload {
        let pullRequest = ConnectRequests.Pull(
            schemeVersion: schemeVersion,
            payload: .init(newSessionIdEnc: newSessionIdEnc)
        )
        let pullResponse = try await webSocketSession.send(pullRequest)

        Log("Connect - Pull action received", module: .connect, severity: .info)

        return pullResponse
    }

    // MARK: - Pull Action Response

    func sendPullActionResponse(dataEnc: Data, isFullSync: Bool = false) async throws {
        let pullActionRequest = ConnectRequests.PullAction(
            schemeVersion: schemeVersion,
            isFullSync: isFullSync,
            payload: .init(dataEnc: dataEnc)
        )
        try await webSocketSession.send(pullActionRequest)

        Log("Connect - Pull action response sended", module: .connect, severity: .info)
    }

    // MARK: - Chunk Transfer

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

    // MARK: - Connection Close

    func closeConnectionWithSuccess() async throws {
        let successRequest = ConnectRequests.CloseWithSuccess(schemeVersion: schemeVersion)
        try await webSocketSession.send(successRequest)

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
