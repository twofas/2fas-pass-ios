// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct InitTransfer: ConnectRequestExpectedResponse {

        let id: UUID = UUID()
        let schemeVersion: ConnectSchemaVersion
        let payload: Payload
        let action: ConnectMessageAction = .initTransfer
        
        struct Payload: ConnectMessagePayload {
            let totalChunks: Int
            let totalSize: Int
            let sha256GzipVaultDataEnc: String
            let fcmTokenEnc: String
            let newSessionIdEnc: String
            let expirationDateEnc: String?
        }
        
        func validateResponse(_ message: ConnectMessage<ConnectMessagePayloadEmpty>) throws {
            if message.action != .initTransferConfirmed {
                throw ConnectWebSocketError.wrongResponseAction
            }
        }
    }
}
