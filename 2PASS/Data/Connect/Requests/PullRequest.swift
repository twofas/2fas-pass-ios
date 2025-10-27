// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct Pull: ConnectRequestExpectedResponse {

        let id: UUID = UUID()
        let schemeVersion: ConnectSchemaVersion
        let payload: Payload
        let action: ConnectMessageAction = .pullRequest
        
        struct Payload: ConnectMessagePayload {
            let newSessionIdEnc: Data
        }
        
        struct ResponsePayload: ConnectMessagePayload {
            let dataEnc: Data
        }
        
        func validateResponse(_ message: ConnectMessage<ResponsePayload>) throws {
            if message.action != .pullRequest {
                throw ConnectWebSocketError.wrongResponseAction
            }
        }
    }
}
