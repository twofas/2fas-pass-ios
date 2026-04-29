// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

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

    /// Read probe used to verify a config before persisting it. Default implementation calls
    /// `fetchIndex()` and treats `.notFound` (HTTP 404) as success — that's the fresh-setup
    /// case where the destination is reachable and credentials are valid but no backup yet
    /// exists. All other errors (`.unauthorized`, `.forbidden`, `.network`, etc.) propagate.
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
}
