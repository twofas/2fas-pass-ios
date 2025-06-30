// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct PullAction: ConnectRequestExpectedResponse {
        
        let id: UUID = UUID()
        let payload: Payload
        let action: ConnectMessageAction = .pullRequestAction
        
        struct Payload: ConnectMessagePayload {
            let dataEnc: Data
        }
        
        func validateResponse(_ message: ConnectMessage<ConnectMessagePayloadEmpty>) throws {
            if message.action != .pullRequestCompleted {
                throw ConnectWebSocketError.wrongResponseAction
            }
        }
    }
}
