// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct AppNotification: Codable {
    public let id: String
    public let expiresAt: Date
    public let data: Payload
    
    public struct Payload: Codable {
        public let messageType: String
        public let notificationId: String
        public let pkEpheBe: String
        public let pkPersBe: String
        public let sigPush: String
        public let timestamp: String
    }
}
