// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct TransferChunk: ConnectRequestExpectedResponse {
        
        let id: UUID = UUID()
        let payload: Payload        
        let action: ConnectMessageAction = .transferChunk
        
        struct Payload: ConnectMessagePayload {
            let chunkIndex: Int
            let chunkSize: Int
            let chunkData: String
        }
        
        struct ResponsePayload: ConnectMessagePayload {
            let chunkIndex: Int
        }
        
        func validateResponse(_ message: ConnectMessage<ResponsePayload>) throws {
            if message.action != .transferChunkConfirmed {
                throw ConnectWebSocketError.wrongResponseAction
            }
        }
    }
}
