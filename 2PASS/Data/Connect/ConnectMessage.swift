// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

struct GenericConnectMessage: Codable {
    let scheme: Int
    let origin: String
    let originVersion: String
    let id: String
    let action: ConnectMessageAction
}

struct ConnectMessage<Payload>: Codable where Payload: ConnectMessagePayload {
    let scheme: Int
    let origin: String
    let originVersion: String
    let id: UUID
    let action: ConnectMessageAction
    let payload: Payload?
}

enum ConnectMessageAction: String, Codable {
    case hello
    case challenge
    case transferChunk
    case initTransfer
    case initTransferConfirmed
    case transferChunkConfirmed
    case transferCompleted
    case closeWithSuccess
    case closeWithError
    case pullRequest
    case pullRequestAction
    case pullRequestCompleted
}
