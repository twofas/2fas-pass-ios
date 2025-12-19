// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum NetworkError: Error {
    public enum ConnectionError {
        case otherError
        case serverError
        case serverHTTPError(status: Int, error: ReturnedError?)
        case parseError
    }
    case emptyData
    case noInternet
    case connection(error: ConnectionError)
}

public struct ReturnedError: Codable {
    public let code: Int?
    public let type: String?
    public let description: String?
    public let reason: String?
}
