// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct PullAction: ConnectRequestExpectedResponse {

        let id: UUID = UUID()
        let schemeVersion: ConnectSchemaVersion
        let isFullSync: Bool
        let payload: Payload
        let action: ConnectMessageAction = .pullRequestAction

        init(schemeVersion: ConnectSchemaVersion, isFullSync: Bool = false, payload: Payload) {
            self.schemeVersion = schemeVersion
            self.isFullSync = isFullSync
            self.payload = payload
        }
        
        struct Payload: ConnectMessagePayload {
            let dataEnc: Data
        }
        
        func validateResponse(_ message: ConnectMessage<ConnectMessagePayloadEmpty>) throws {
            if isFullSync {
                if message.action != .initTransferConfirmed {
                    throw ConnectWebSocketError.wrongResponseAction
                }
            } else {
                if message.action != .pullRequestCompleted {
                    throw ConnectWebSocketError.wrongResponseAction
                }
            }
        }
    }
}
