// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension ConnectRequests {
    
    struct CloseWithSuccess: ConnectRequestWithoutResponse {
        typealias Payload = ConnectMessagePayloadEmpty

        let id: UUID = UUID()
        let schemeVersion: ConnectSchemaVersion
        let payload: Payload = ConnectMessagePayloadEmpty()
        
        let action: ConnectMessageAction = .closeWithSuccess
    }
}
