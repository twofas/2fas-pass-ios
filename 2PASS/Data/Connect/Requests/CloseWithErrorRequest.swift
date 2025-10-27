// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct CloseWithError: ConnectRequestWithoutResponse {
        let id: UUID = UUID()
        let schemeVersion: ConnectSchemaVersion
        let payload: Payload
        let action: ConnectMessageAction = .closeWithError
        
        struct Payload: ConnectMessagePayload {
            let errorCode: Int
            let errorMessage: String?
        }
    }
}

extension ConnectRequests.CloseWithError.Payload {
    
    init(error: Error) {
        switch error {
        case ConnectError.saltVerificationFailed:
            self.errorCode = 1020
        case ConnectError.missingItem:
            self.errorCode = 1001
        default:
            self.errorCode = 1000
        }
        
        self.errorMessage = nil
    }
}
