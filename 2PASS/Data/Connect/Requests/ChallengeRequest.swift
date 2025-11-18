// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct Challenge: ConnectRequestExpectedResponse {

        let id: UUID = UUID()
        let schemeVersion: ConnectSchemaVersion
        let payload: Payload
        let action: ConnectMessageAction = .challenge
        
        struct Payload: ConnectMessagePayload {
            let pkEpheMa: String
            let hkdfSalt: String
        }
        
        struct ResponsePayload: ConnectMessagePayload {
            let hkdfSaltEnc: String
        }
        
        func validateResponse(_ message: ConnectMessage<ResponsePayload>) throws {
            if message.action != .challenge {
                throw ConnectWebSocketError.wrongResponseAction
            }
        }
    }
}
