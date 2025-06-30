// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension MainRepositoryImpl {
    func fetchFile(from url: URL, completion: @escaping (Result<Data, NetworkError>) -> Void) {
        network.fetchFile(from: url, completion: completion)
    }

    func cachedImage(from url: URL) -> Data? {
        URLCache.shared.cachedResponse(for: URLRequest(url: url))?.data
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            let cachedResponse = CachedURLResponse(response: httpResponse, data: Data(), userInfo: nil, storagePolicy: .allowed)
            URLCache.shared.storeCachedResponse(cachedResponse, for: URLRequest(url: url))
        }
        
        return data
    }
}
