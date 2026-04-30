// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public struct S3ServiceConfig: Codable, Equatable, Sendable {
    public let endpoint: URL
    public let region: String
    public let bucket: String
    public let accessKeyId: String
    public let secretAccessKey: String
    public let allowTLSOff: Bool

    public init(
        endpoint: URL,
        region: String,
        bucket: String,
        accessKeyId: String,
        secretAccessKey: String,
        allowTLSOff: Bool = false
    ) {
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.allowTLSOff = allowTLSOff
    }
}

public enum S3ServiceError: Error, Sendable {
    case ssl
    case network(underlying: any Error)
    case server(underlying: any Error)
    case url(underlying: any Error)
    case invalidResponse
}

public struct S3URLRequest: Sendable, Equatable {
    public enum HTTPMethod: String, Sendable {
        case get = "GET"
        case put = "PUT"
        case delete = "DELETE"
        case head = "HEAD"
    }

    public var objectKey: String
    public var httpMethod: HTTPMethod
    public var httpBody: Data?
    public var allHTTPHeaderFields: [String: String]

    public init(objectKey: String, httpMethod: HTTPMethod = .get) {
        self.objectKey = objectKey
        self.httpMethod = httpMethod
        self.httpBody = nil
        self.allHTTPHeaderFields = [:]
    }

    public mutating func setValue(_ value: String?, forHTTPHeaderField field: String) {
        if let value {
            allHTTPHeaderFields[field] = value
        } else {
            allHTTPHeaderFields.removeValue(forKey: field)
        }
    }

    public func value(forHTTPHeaderField field: String) -> String? {
        allHTTPHeaderFields[field]
    }
}

public final class S3ServiceSession: Sendable {
    public let config: S3ServiceConfig
    private let session: URLSession

    public init(config: S3ServiceConfig) {
        self.config = config
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 30
        sessionConfiguration.timeoutIntervalForResource = 120
        // GET requests benefit from conditional revalidation (304 saves the body on unchanged
        // vaults). Non-GET methods opt out of cache lookups per-request in `buildURLRequest`,
        // because some S3-compatible backends respond `501 NotImplemented` when conditional
        // headers ride along with writes/deletes.
        sessionConfiguration.requestCachePolicy = .reloadRevalidatingCacheData
        sessionConfiguration.networkServiceType = .responsiveData
        sessionConfiguration.waitsForConnectivity = true
        self.session = URLSession(configuration: sessionConfiguration)
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func data(for request: S3URLRequest) async throws(S3ServiceError) -> (Data, HTTPURLResponse) {
        let urlRequest = buildURLRequest(from: request)
        let delegate: URLSessionTaskDelegate? = config.allowTLSOff ? TLSBypassDelegate() : nil
        do {
            let (data, response) = try await session.data(for: urlRequest, delegate: delegate)
            guard let http = response as? HTTPURLResponse else {
                throw S3ServiceError.invalidResponse
            }
            return (data, http)
        } catch let error as S3ServiceError {
            throw error
        } catch {
            Log("S3ServiceSession: transport error \(error)", module: .backup)
            throw Self.mapTransportError(error)
        }
    }
}

private extension S3ServiceSession {
    func buildURLRequest(from request: S3URLRequest) -> URLRequest {
        let url = config.endpoint
            .appendingPathComponent(config.bucket, isDirectory: false)
            .appendingPathComponent(request.objectKey, isDirectory: false)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.httpMethod.rawValue
        urlRequest.httpBody = request.httpBody
        if request.httpMethod != .get {
            urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        }
        for (name, value) in request.allHTTPHeaderFields {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let bodyHash = S3SigV4Signer.sha256Hex(request.httpBody ?? Data())
        S3SigV4Signer.sign(
            request: &urlRequest,
            bodySHA256Hex: bodyHash,
            now: Date(),
            config: config
        )
        return urlRequest
    }

    static func mapTransportError(_ error: any Error) -> S3ServiceError {
        let code = (error as NSError).code
        if code.isSSLError { return .ssl }
        if code.isNetworkError { return .network(underlying: error) }
        if code.isServerError { return .server(underlying: error) }
        if code.isURLError { return .url(underlying: error) }
        return .server(underlying: error)
    }
}

private final class TLSBypassDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: serverTrust))
    }
}
