// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

final class BackupS3ServiceSession: BackupFileServiceSession {
    public let config: S3ServiceConfig
    private let session: S3ServiceSession

    public init(config: S3ServiceConfig) {
        self.config = config
        self.session = S3ServiceSession(config: config)
    }

    public func fetchIndex() async throws(BackupFileServiceError) -> Data {
        let request = Self.request(for: .index)
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.read)
        return data
    }

    public func testConnection() async throws(BackupFileServiceError) {
        // HEAD on the bucket root (no object key) — a key-level GET can't distinguish
        // "bucket missing" from "index missing" on Ceph-backed backends (e.g. Hetzner).
        let probeSession = S3ServiceSession(config: config, mode: .probe)
        let request = S3URLRequest(objectKey: "", httpMethod: .head)
        let (_, response) = try await perform(request, on: probeSession)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.read)
    }

    public func fetchLock() async throws(BackupFileServiceError) -> Data {
        let request = Self.request(for: .indexLock)
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.read)
        return data
    }

    public func fetchVault(vaultID: UUID) async throws(BackupFileServiceError) -> Data {
        let request = Self.request(for: .vault(vaultID: vaultID))
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.read)
        return data
    }

    public func writeIndex(_ data: Data) async throws(BackupFileServiceError) {
        let request = Self.putRequest(for: .index, body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func writeLock(_ data: Data) async throws(BackupFileServiceError) {
        let request = Self.putRequest(for: .indexLock, body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func writeVault(_ data: Data, vaultID: UUID) async throws(BackupFileServiceError) {
        let request = Self.putRequest(for: .vaultTemp(vaultID: vaultID), body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func writeDecryptedVault(_ data: Data, vaultID: UUID) async throws(BackupFileServiceError) {
        let request = Self.putRequest(for: .vaultDecrypted(vaultID: vaultID), body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func finalizeVault(vaultID: UUID) async throws(BackupFileServiceError) {
        let tempResource: BackupFileResource = .vaultTemp(vaultID: vaultID)
        let finalResource: BackupFileResource = .vault(vaultID: vaultID)

        var copyRequest = Self.request(.put, for: finalResource)
        // AWS spec: x-amz-copy-source must be URI-encoded per segment (the separating `/`
        // stays literal). Encoding here — not during URL construction — keeps the header
        // value byte-identical to what SigV4 folds into the canonical request.
        let encodedBucket = config.bucket.addingPercentEncoding(withAllowedCharacters: .awsUnreserved) ?? config.bucket
        let encodedKey = tempResource.filename.addingPercentEncoding(withAllowedCharacters: .awsUnreserved) ?? tempResource.filename
        copyRequest.setValue("/\(encodedBucket)/\(encodedKey)", forHTTPHeaderField: "x-amz-copy-source")
        let (_, copyResponse) = try await perform(copyRequest)
        try validateStatus(copyResponse, expected: BackupFileServiceExpectedStatus.read)

        let deleteRequest = Self.request(.delete, for: tempResource)
        let (_, deleteResponse) = try await perform(deleteRequest)
        try validateStatus(deleteResponse, expected: BackupFileServiceExpectedStatus.deleted)
    }

    public func deleteLock() async throws(BackupFileServiceError) {
        let request = Self.request(.delete, for: .indexLock)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.deleted)
    }
}

private extension BackupS3ServiceSession {
    static func request(_ method: S3URLRequest.HTTPMethod = .get, for resource: BackupFileResource) -> S3URLRequest {
        S3URLRequest(objectKey: resource.filename, httpMethod: method)
    }

    static func putRequest(for resource: BackupFileResource, body: Data) -> S3URLRequest {
        var request = Self.request(.put, for: resource)
        request.httpBody = body
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        return request
    }

    func perform(
        _ request: S3URLRequest,
        on session: S3ServiceSession? = nil
    ) async throws(BackupFileServiceError) -> (Data, HTTPURLResponse) {
        let activeSession = session ?? self.session
        Log(
            "BackupS3ServiceSession: request \(request.httpMethod.rawValue) \(request.objectKey) (body \(request.httpBody?.count ?? 0) B)",
            module: .backup
        )
        do {
            let (data, response) = try await activeSession.data(for: request)
            if response.statusCode >= 400, let body = String(data: data, encoding: .utf8) {
                Log(
                    "BackupS3ServiceSession: response \(response.statusCode) \(request.objectKey) (body \(data.count) B): \(body)",
                    module: .backup
                )
            } else {
                Log(
                    "BackupS3ServiceSession: response \(response.statusCode) \(request.objectKey) (body \(data.count) B)",
                    module: .backup
                )
            }
            return (data, response)
        } catch {
            throw Self.mapServiceError(error)
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
