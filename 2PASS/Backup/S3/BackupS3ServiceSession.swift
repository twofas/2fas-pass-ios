// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public final class BackupS3ServiceSession: BackupFileServiceSession {
    public let config: S3ServiceConfig
    private let session: S3ServiceSession

    public init(config: S3ServiceConfig) {
        self.config = config
        self.session = S3ServiceSession(config: config)
    }

    public func getIndex() async throws(BackupFileServiceError) -> Data {
        let request = Self.request(for: .index)
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: [200])
        return data
    }

    public func getLock() async throws(BackupFileServiceError) -> Data {
        let request = Self.request(for: .indexLock)
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: [200])
        return data
    }

    public func getVault(vaultID: String) async throws(BackupFileServiceError) -> Data {
        let request = Self.request(for: .vault(vaultID: vaultID))
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: [200])
        return data
    }

    public func writeIndex(_ data: Data) async throws(BackupFileServiceError) {
        let request = Self.putRequest(for: .index, body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: [200, 201, 204])
    }

    public func writeLock(_ data: Data) async throws(BackupFileServiceError) {
        let request = Self.putRequest(for: .indexLock, body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: [200, 201, 204])
    }

    public func writeVault(_ data: Data, vaultID: String) async throws(BackupFileServiceError) {
        let request = Self.putRequest(for: .vaultTemp(vaultID: vaultID), body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: [200, 201, 204])
    }

    public func writeDecryptedVault(_ data: Data, vaultID: String) async throws(BackupFileServiceError) {
        let request = Self.putRequest(for: .vaultDecrypted(vaultID: vaultID), body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: [200, 201, 204])
    }

    public func move(vaultID: String) async throws(BackupFileServiceError) {
        let tempKey: ObjectKey = .vaultTemp(vaultID: vaultID)
        let finalKey: ObjectKey = .vault(vaultID: vaultID)

        var copyRequest = Self.request(.put, for: finalKey)
        copyRequest.setValue("/\(config.bucket)/\(tempKey.path)", forHTTPHeaderField: "x-amz-copy-source")
        let (_, copyResponse) = try await perform(copyRequest)
        try validateStatus(copyResponse, expected: [200])

        let deleteRequest = Self.request(.delete, for: tempKey)
        let (_, deleteResponse) = try await perform(deleteRequest)
        try validateStatus(deleteResponse, expected: [200, 204])
    }

    public func deleteLock() async throws(BackupFileServiceError) {
        let request = Self.request(.delete, for: .indexLock)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: [200, 204])
    }
}

private extension BackupS3ServiceSession {
    enum ObjectKey {
        case index
        case indexLock
        case vault(vaultID: String)
        case vaultTemp(vaultID: String)
        case vaultDecrypted(vaultID: String)

        var path: String {
            switch self {
            case .index:
                "index.2faspass"
            case .indexLock:
                "index.2faspass.lock"
            case .vault(let vaultID):
                "\(vaultID.lowercased())_v\(Config.webDAVURLSchemaVersion).2faspass"
            case .vaultTemp(let vaultID):
                "\(vaultID.lowercased())_v\(Config.webDAVURLSchemaVersion).2faspass.tmp"
            case .vaultDecrypted(let vaultID):
                "\(vaultID.lowercased())_v\(Config.webDAVURLSchemaVersion).2faspass-decrypted_ios.json"
            }
        }
    }

    static func request(_ method: S3URLRequest.HTTPMethod = .get, for key: ObjectKey) -> S3URLRequest {
        S3URLRequest(objectKey: key.path, httpMethod: method)
    }

    static func putRequest(for key: ObjectKey, body: Data) -> S3URLRequest {
        var request = Self.request(.put, for: key)
        request.httpBody = body
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        return request
    }

    func perform(_ request: S3URLRequest) async throws(BackupFileServiceError) -> (Data, HTTPURLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw Self.mapServiceError(error)
        }
    }

    func validateStatus(_ response: HTTPURLResponse, expected: Set<Int>) throws(BackupFileServiceError) {
        if expected.contains(response.statusCode) { return }
        Log("BackupS3ServiceSession: unexpected status \(response.statusCode)", module: .backup)
        switch response.statusCode {
        case 401: throw .unauthorized
        case 403: throw .forbidden
        case 404: throw .notFound
        case 405: throw .methodNotAllowed
        default: throw .unexpectedStatus(code: response.statusCode)
        }
    }

    static func mapServiceError(_ error: S3ServiceError) -> BackupFileServiceError {
        switch error {
        case .ssl:
            .ssl
        case .network(let underlying):
            .network(underlying: underlying)
        case .server(let underlying):
            .server(underlying: underlying)
        case .url(let underlying):
            .url(underlying: underlying)
        case .invalidResponse:
            .invalidResponse
        }
    }
}
