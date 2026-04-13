// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

final class TwoFASShareServiceSession {

    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.session = URLSession(configuration: .default)
        self.baseURL = baseURL
    }

    func createSecret(request: ShareSecretRequest) async throws -> CreateShareSecretResponse {
        let url = baseURL.appending(path: "api/secret")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data = try await session.validatedData(for: urlRequest)
        return try JSONDecoder().decode(CreateShareSecretResponse.self, from: data)
    }

    func fetchSecret(id: String) async throws -> SharedSecretResponse {
        let url = baseURL.appending(path: "api/secret/\(id)")
        let data = try await session.validatedData(from: url)
        return try JSONDecoder().decode(SharedSecretResponse.self, from: data)
    }
}
