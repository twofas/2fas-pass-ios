// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum BackupSyncError: Error, Sendable {
    case unauthorized
    case forbidden
    case notConfigured
    case methodNotAllowed
    case schemaNotSupported(version: Int)
    case limitDevicesReached
    case passwordChanged
    case cancelled
    case network(underlying: any Error & Sendable)
    case server(underlying: any Error & Sendable)
    case ssl
    case export(BackupVaultExportError)
    case invalidResponse
    case unexpected(String)
    /// iCloud-specific terminal condition: account signed out, container unavailable, or
    /// equivalent state where the user must take action in Settings before sync can resume.
    /// Distinct from `.unauthorized` (which the UX layer treats as "ask for credentials") and
    /// `.network` (transient, retried). Other backends never throw this case.
    case iCloudUnavailable
}

extension BackupSyncError {
    static func from(transport error: BackupFileServiceError) -> BackupSyncError {
        switch error {
        case .unauthorized:
            .unauthorized
        case .forbidden:
            .forbidden
        case .notFound:
            .notConfigured
        case .methodNotAllowed:
            .methodNotAllowed
        case .unexpectedStatus(let code):
            .unexpected("status \(code)")
        case .ssl:
            .ssl
        case .network(let underlying):
            .network(underlying: underlying as (any Error & Sendable))
        case .server(let underlying):
            .server(underlying: underlying as (any Error & Sendable))
        case .url(let underlying):
            .network(underlying: underlying as (any Error & Sendable))
        case .invalidResponse:
            .invalidResponse
        }
    }

    static func from(decode error: ExchangeDecodeError) -> BackupSyncError {
        switch error {
        case .schemaNotSupported(version: let v):
            .schemaNotSupported(version: v)
        }
    }

    static func from(merge error: BackupLocalMergeError) -> BackupSyncError {
        switch error {
        case .errorDecrypting, .needsPassword:
            .notConfigured
        case .otherDeviceId:
            .limitDevicesReached
        case .passwordChanged:
            .passwordChanged
        }
    }
}

extension BackupSyncError {
    /// True when the error describes a transient condition that a retry loop should handle.
    var isTransient: Bool {
        switch self {
        case .network, .server, .invalidResponse:
            true
        default:
            false
        }
    }
}
