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
    /// iCloud terminal condition (account signed out, container unavailable, …) where the
    /// user must act in Settings before sync resumes. Distinct from `.unauthorized` (ask for
    /// credentials) and `.network` (transient).
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

extension BackupSyncError: LocalizedError {
    /// `nil` for `.cancelled` so user cancels don't surface as errors. `.network` / `.server`
    /// use a static localized message instead of the underlying NSError's English description.
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return String(localized: .backupSyncErrorUnauthorized)
        case .forbidden:
            return String(localized: .backupSyncErrorForbidden)
        case .notConfigured:
            return String(localized: .backupSyncErrorNotConfigured)
        case .methodNotAllowed:
            return String(localized: .backupSyncErrorMethodNotAllowed)
        case .schemaNotSupported(let version):
            return String(localized: .backupSyncErrorSchemaNotSupported(version))
        case .limitDevicesReached:
            return String(localized: .backupSyncErrorLimitDevicesReached)
        case .passwordChanged:
            return String(localized: .backupSyncErrorPasswordChanged)
        case .cancelled:
            return nil
        case .network:
            return String(localized: .backupSyncErrorNetwork)
        case .server:
            return String(localized: .backupSyncErrorServer)
        case .ssl:
            return String(localized: .backupSyncErrorSsl)
        case .export:
            return String(localized: .backupSyncErrorExport)
        case .invalidResponse:
            return String(localized: .backupSyncErrorInvalidResponse)
        case .unexpected(let message):
            return String(localized: .backupSyncErrorUnexpected(message))
        case .iCloudUnavailable:
            return String(localized: .backupSyncErrorIcloudUnavailable)
        }
    }
}
