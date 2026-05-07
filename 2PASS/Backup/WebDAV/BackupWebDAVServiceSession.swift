// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

final class BackupWebDAVServiceSession: BackupFileServiceSession {
    public let config: BackupWebDAVConfig
    private let session: URLSession
    private let sessionDelegate: TLSBypassDelegate?

    public init(config: BackupWebDAVConfig) {
        self.config = config

        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 30
        sessionConfiguration.timeoutIntervalForResource = 120
        sessionConfiguration.requestCachePolicy = .reloadRevalidatingCacheData
        sessionConfiguration.networkServiceType = .responsiveData
        sessionConfiguration.waitsForConnectivity = true

        if config.allowTLSOff {
            let delegate = TLSBypassDelegate()
            self.sessionDelegate = delegate
            self.session = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
        } else {
            self.sessionDelegate = nil
            self.session = URLSession(configuration: sessionConfiguration)
        }
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func fetchIndex() async throws(BackupFileServiceError) -> Data {
        let request = buildRequest(method: .get, for: .index)
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.read)
        return data
    }

    public func testConnection() async throws(BackupFileServiceError) {
        // PROPFIND/Depth:0 on the collection — bad paths return 404; fresh setups still return 207.
        let (_, response) = try await perform(buildPropfindRequest())

        switch response.statusCode {
        case 200, 207:
            return
        case 405, 501:
            // PROPFIND blocked by server/proxy — fall back to OPTIONS to at least confirm reachability.
            let (_, optionsResponse) = try await perform(buildOptionsRequest())
            try validateStatus(optionsResponse, expected: [200, 204])
        default:
            try validateStatus(response, expected: [200, 207])
        }
    }

    public func fetchLock() async throws(BackupFileServiceError) -> Data {
        let request = buildRequest(method: .get, for: .indexLock)
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.read)
        return data
    }

    public func fetchVault(vaultID: UUID) async throws(BackupFileServiceError) -> Data {
        let request = buildRequest(method: .get, for: .vault(vaultID: vaultID))
        let (data, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.read)
        return data
    }

    public func writeIndex(_ data: Data) async throws(BackupFileServiceError) {
        let request = buildPutRequest(for: .index, body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func writeLock(_ data: Data) async throws(BackupFileServiceError) {
        let request = buildPutRequest(for: .indexLock, body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func writeVault(_ data: Data, vaultID: UUID) async throws(BackupFileServiceError) {
        let request = buildPutRequest(for: .vaultTemp(vaultID: vaultID), body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func writeDecryptedVault(_ data: Data, vaultID: UUID) async throws(BackupFileServiceError) {
        let request = buildPutRequest(for: .vaultDecrypted(vaultID: vaultID), body: data)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func finalizeVault(vaultID: UUID) async throws(BackupFileServiceError) {
        let from: BackupFileResource = .vaultTemp(vaultID: vaultID)
        let to: BackupFileResource = .vault(vaultID: vaultID)

        guard let destinationURL = url(for: to) else {
            throw .invalidResponse
        }

        var request = buildRequest(method: .move, for: from)
        request.setValue(destinationURL.absoluteString, forHTTPHeaderField: "Destination")
        request.setValue("T", forHTTPHeaderField: "Overwrite")

        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.written)
    }

    public func deleteLock() async throws(BackupFileServiceError) {
        let request = buildRequest(method: .delete, for: .indexLock)
        let (_, response) = try await perform(request)
        try validateStatus(response, expected: BackupFileServiceExpectedStatus.deleted)
    }
}

private extension BackupWebDAVServiceSession {
    enum HTTPMethod: String {
        case get = "GET"
        case put = "PUT"
        case delete = "DELETE"
        case move = "MOVE"
        case propfind = "PROPFIND"
        case options = "OPTIONS"
    }

    static let propfindBody = Data(#"""
    <?xml version="1.0" encoding="utf-8"?>
    <propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>
    """#.utf8)

    func url(for resource: BackupFileResource) -> URL? {
        URL(string: resource.filename, relativeTo: config.normalizedURL)
    }

    func buildRequest(method: HTTPMethod, for resource: BackupFileResource) -> URLRequest {
        let url = self.url(for: resource) ?? config.normalizedURL
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        switch method {
        case .get:
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        case .put, .delete, .move, .propfind, .options:
            break
        }

        authorize(&request)
        return request
    }

    func buildPutRequest(for resource: BackupFileResource, body: Data) -> URLRequest {
        var request = buildRequest(method: .put, for: resource)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.httpBody = body
        return request
    }

    func buildPropfindRequest() -> URLRequest {
        var request = URLRequest(url: config.normalizedURL)
        request.httpMethod = HTTPMethod.propfind.rawValue
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.propfindBody
        authorize(&request)
        return request
    }

    func buildOptionsRequest() -> URLRequest {
        var request = URLRequest(url: config.normalizedURL)
        request.httpMethod = HTTPMethod.options.rawValue
        authorize(&request)
        return request
    }

    func authorize(_ request: inout URLRequest) {
        let login = config.login ?? ""
        let password = config.password ?? ""
        let raw = "\(login):\(password)"
        guard let data = raw.data(using: .utf8) else {
            Log("BackupWebDAVServiceSession: can't encode basic auth credentials", module: .backup)
            return
        }
        request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
    }

    func perform(_ request: URLRequest) async throws(BackupFileServiceError) -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw BackupFileServiceError.invalidResponse
            }
            return (data, http)
        } catch let error as BackupFileServiceError {
            throw error
        } catch {
            Log("BackupWebDAVServiceSession: transport error \(error)", module: .backup)
            throw Self.mapTransportError(error)
        }
    }

    static func mapTransportError(_ error: any Error) -> BackupFileServiceError {
        let code = (error as NSError).code
        if code.isSSLError { return .ssl }
        if code.isUserAuthError { return .unauthorized }
        if code.isNetworkError { return .network(underlying: error) }
        if code.isServerError { return .server(underlying: error) }
        if code.isURLError { return .url(underlying: error) }
        return .server(underlying: error)
    }
}

private final class TLSBypassDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}
