// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

struct ConnectTag: Codable {
    public let id: String
    public let name: String
    public let color: String?
    public let position: Int
    public let updatedAt: Int
}
