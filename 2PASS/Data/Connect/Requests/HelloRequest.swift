// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct Hello: ConnectRequestExpectedResponse {

        let id: UUID = UUID()
        let schemeVersion: ConnectSchemaVersion
        let payload: Payload
        let action: ConnectMessageAction = .hello
        
        struct Payload: ConnectMessagePayload {
            let deviceId: String
            let deviceName: String
            let deviceOs: String
            
            // V2
            let supportedFeatures: [String]?
        }
        
        struct ResponsePayload: ConnectMessagePayload {
            let browserName: String
            let browserVersion: String
            let browserExtName: String
            
            // V2
            let supportedFeatures: [String]?
        }
        
        func validateResponse(_ message: ConnectMessage<ResponsePayload>) throws {
            if message.action != .hello {
                throw ConnectWebSocketError.wrongResponseAction
            }
        }
    }
}
