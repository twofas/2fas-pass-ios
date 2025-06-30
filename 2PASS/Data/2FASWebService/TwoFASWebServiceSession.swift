// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

final class TwoFASWebServiceSession {
    
    let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL) {
        self.session = URLSession(configuration: .default)
        self.baseURL = baseURL
    }
    
    func fetchNotifications(forDeviceId deviceId: UUID) async throws -> [AppNotification] {
        let url = baseURL.appending(path: "device/\(deviceId)/notifications")
        let (data, _) = try await session.data(from: url)
        
        let decoder = JSONDecoder()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        return try decoder.decode(AppNotifications.self, from: data).notifications ?? []
    }
    
    func deleteNotification(id: String, deviceId: UUID) async throws {
        let url = baseURL.appending(path: "device/\(deviceId)/notifications/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        _ = try await session.data(for: request)
    }
}
