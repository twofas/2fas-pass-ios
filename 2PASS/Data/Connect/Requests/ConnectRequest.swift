// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

protocol ConnectRequest: Identifiable {
    associatedtype Payload: ConnectMessagePayload

    var id: UUID { get }
    var payload: Payload { get }
    var action: ConnectMessageAction { get }
    var schemeVersion: ConnectSchemaVersion { get }
}

protocol ConnectRequestWithoutResponse: ConnectRequest {
}

protocol ConnectRequestExpectedResponse: ConnectRequest {
    associatedtype ResponsePayload: ConnectMessagePayload
    func validateResponse(_ message: ConnectMessage<ResponsePayload>) throws
}

protocol ConnectMessagePayload: Codable {}

struct ConnectMessagePayloadEmpty: ConnectMessagePayload {}

// Namespace for requests
enum ConnectRequests {}
