// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum BackupFileServiceError: Error, Sendable {
    case unauthorized
    case forbidden
    case notFound
    case methodNotAllowed
    case unexpectedStatus(code: Int)
    case ssl
    case network(underlying: any Error)
    case server(underlying: any Error)
    case url(underlying: any Error)
    case invalidResponse
}

public protocol BackupFileServiceSession: Sendable {
    func fetchIndex() async throws(BackupFileServiceError) -> Data
    func fetchLock() async throws(BackupFileServiceError) -> Data
    func fetchVault(vaultID: UUID) async throws(BackupFileServiceError) -> Data

    func writeIndex(_ data: Data) async throws(BackupFileServiceError)
    func writeLock(_ data: Data) async throws(BackupFileServiceError)
    func writeVault(_ data: Data, vaultID: UUID) async throws(BackupFileServiceError)
    func writeDecryptedVault(_ data: Data, vaultID: UUID) async throws(BackupFileServiceError)

    func finalizeVault(vaultID: UUID) async throws(BackupFileServiceError)
    func deleteLock() async throws(BackupFileServiceError)

    func testConnection() async throws(BackupFileServiceError)
}

public extension BackupFileServiceSession {
    func testConnection() async throws(BackupFileServiceError) {
        do {
            _ = try await fetchIndex()
        } catch BackupFileServiceError.notFound {
            return
        }
    }

    func validateStatus(_ response: HTTPURLResponse, expected: Set<Int>) throws(BackupFileServiceError) {
        if expected.contains(response.statusCode) { return }
        Log("\(String(describing: type(of: self))): unexpected status \(response.statusCode)", module: .backup)
        switch response.statusCode {
        case 401: throw .unauthorized
        case 403: throw .forbidden
        case 404: throw .notFound
        case 405: throw .methodNotAllowed
        default: throw .unexpectedStatus(code: response.statusCode)
        }
    }
}

enum BackupFileServiceExpectedStatus {
    static let read: Set<Int> = [200]
    static let written: Set<Int> = [200, 201, 204]
    static let deleted: Set<Int> = [200, 204]
}
