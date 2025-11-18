// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct TransferLastChunk: ConnectRequestExpectedResponse {

        let id: UUID = UUID()
        let schemeVersion: ConnectSchemaVersion
        let payload: Payload
        let action: ConnectMessageAction = .transferChunk
        
        struct Payload: ConnectMessagePayload {
            let chunkIndex: Int
            let chunkSize: Int
            let chunkData: String
        }
        
        func validateResponse(_ message: ConnectMessage<ConnectMessagePayloadEmpty>) throws {
            if message.action != .transferCompleted {
                throw ConnectWebSocketError.wrongResponseAction
            }
        }
    }
}
