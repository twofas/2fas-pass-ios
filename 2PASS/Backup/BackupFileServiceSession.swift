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
    func getIndex() async throws(BackupFileServiceError) -> Data
    func getLock() async throws(BackupFileServiceError) -> Data
    func getVault(vaultID: String) async throws(BackupFileServiceError) -> Data

    func writeIndex(_ data: Data) async throws(BackupFileServiceError)
    func writeLock(_ data: Data) async throws(BackupFileServiceError)
    func writeVault(_ data: Data, vaultID: String) async throws(BackupFileServiceError)
    func writeDecryptedVault(_ data: Data, vaultID: String) async throws(BackupFileServiceError)

    func move(vaultID: String) async throws(BackupFileServiceError)
    func deleteLock() async throws(BackupFileServiceError)
}
