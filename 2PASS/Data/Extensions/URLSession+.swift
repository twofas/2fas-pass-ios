// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum HTTPError: Error {
    case invalidResponse
    case statusCode(Int)
}

extension URLSession {

    func validatedData(from url: URL) async throws -> Data {
        let (data, response) = try await data(from: url)
        try Self.validate(response)
        return data
    }

    func validatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await data(for: request)
        try Self.validate(response)
        return data
    }

    private static func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HTTPError.statusCode(httpResponse.statusCode)
        }
    }
}
