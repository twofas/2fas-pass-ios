// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public struct BackupWebDAVConfig: Codable, Equatable {
    public let baseURL: String
    public let normalizedURL: URL
    public let lockTime: Int
    public let allowTLSOff: Bool
    public let vid: String?
    public let login: String?
    public let password: String?
    
    public init(
        baseURL: String,
        normalizedURL: URL,
        lockTime: Int,
        allowTLSOff: Bool,
        vid: String?,
        login: String?,
        password: String?
    ) {
        self.baseURL = baseURL
        self.normalizedURL = normalizedURL
        self.lockTime = lockTime
        self.allowTLSOff = allowTLSOff
        self.vid = vid?.lowercased()
        self.login = login
        self.password = password
    }
    
    public init(baseURL: String, normalizedURL: URL, allowTLSOff: Bool, login: String?, password: String?) {
        self.baseURL = baseURL
        self.normalizedURL = normalizedURL
        self.lockTime = Config.webDAVLockFileTime
        self.allowTLSOff = allowTLSOff
        self.vid = nil
        self.login = login
        self.password = password
    }
}

public enum BackupWebDAVOperationGET {
    case index
    case indexLock
    case vid
    
    func url(for baseURL: URL, vid: String?) -> URL? {
        switch self {
        case .index: return URL(string: "index.2faspass", relativeTo: baseURL)
        case .indexLock: return URL(string: "index.2faspass.lock", relativeTo: baseURL)
        case .vid:
            guard let vid = vid?.lowercased() else {
                return nil
            }
            return URL(string: "\(vid)_v\(Config.schemaVersion).2faspass", relativeTo: baseURL)
        }
    }
}

public enum BackupWebDAVOperationPUT {
    case index
    case indexLock
    case vid
    case decryptedVid
    
    func url(for baseURL: URL, vid: String?) -> URL? {
        switch self {
        case .index: return URL(string: "index.2faspass", relativeTo: baseURL)
        case .indexLock: return URL(string: "index.2faspass.lock", relativeTo: baseURL)
        case .vid:
            guard let vid = vid?.lowercased() else {
                return nil
            }
            return URL(string: "\(vid)_v\(Config.schemaVersion).2faspass.tmp", relativeTo: baseURL)
        case .decryptedVid:
            guard let vid = vid?.lowercased() else {
                return nil
            }
            return URL(string: "\(vid)_v\(Config.schemaVersion).2faspass-decrypted_ios.json", relativeTo: baseURL)
        }
    }
}

public enum BackupWebDAVOperationMOVE {
    case vid
    
    func urls(for baseURL: URL, vid: String?) -> (from: URL, to: URL)? {
        switch self {
        case .vid:
            guard let vid = vid?.lowercased(),
                  let from = URL(string: "\(vid)_v\(Config.schemaVersion).2faspass.tmp", relativeTo: baseURL),
                  let to = URL(string: "\(vid)_v\(Config.schemaVersion).2faspass", relativeTo: baseURL)
            else { return nil }
            return (from: from, to: to)
        }
    }
}

public enum BackupWebDAVOperationDELETE {
    case indexLock
    
    func url(for baseURL: URL, vid: String?) -> URL? {
        switch self {
        case .indexLock: URL(string: "index.2faspass.lock", relativeTo: baseURL)
        }
    }
}


final class BackupWebDAVConnection {
    private let sessionDelegate = SessionDelegate()
    private let requestsBuilder: BackupWebDAVRequestBuilder
    private let responseHandler: BackupWebDAVResponseHandler
    private var session: URLSession?
    
    private let configuration: URLSessionConfiguration = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadRevalidatingCacheData
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 60
        config.networkServiceType = .responsiveData
        config.waitsForConnectivity = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsCellularAccess = true
        
        return config
    }()
    
    private var config: BackupWebDAVConfig?
    
    init() {
        requestsBuilder = BackupWebDAVRequestBuilder()
        responseHandler = BackupWebDAVResponseHandler()
    }
    
    func setConnectionConfig(_ config: BackupWebDAVConfig) {
        self.config = config
        session?.invalidateAndCancel()
        session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
        sessionDelegate.setCredentials(allowTLSOff: config.allowTLSOff, login: config.login, password: config.password)
    }
    
    func get(operation: BackupWebDAVOperationGET, completion: @escaping (Result<Data, BackupWebDAVResponseError>) -> Void) {
        guard let config, let url = operation.url(for: config.normalizedURL, vid: config.vid) else {
            completion(.failure(.generalError))
            return
        }
        let request = requestsBuilder.buildRequest(of: .get(
            url: url,
            login: config.login,
            password: config.password
        ))
        session?.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            completion(responseHandler.handleGetFileResponse(response, data: data, error: error))
        }
        .resume()
    }
    
    func put(
        operation: BackupWebDAVOperationPUT,
        fileContents: Data,
        completion: @escaping (Result<Void,
        BackupWebDAVResponseError>) -> Void
    ) {
        guard let config, let url = operation.url(for: config.normalizedURL, vid: config.vid) else {
            completion(.failure(.generalError))
            return
        }
        let request = requestsBuilder.buildRequest(of: .write(
            url: url,
            fileContents: fileContents,
            login: config.login,
            password: config.password
        ))
        session?.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            completion(responseHandler.handleWriteFileResponse(response, data: data, error: error))
        }
        .resume()
    }
    
    func move(operation: BackupWebDAVOperationMOVE, completion: @escaping (Result<Void, BackupWebDAVResponseError>) -> Void) {
        guard let config, let (from, to) = operation.urls(for: config.normalizedURL, vid: config.vid) else {
            completion(.failure(.generalError))
            return
        }
        let request = requestsBuilder.buildRequest(of: .move(
            url: from,
            destination: to,
            login: config.login,
            password: config.password
        ))
        session?.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            completion(responseHandler.handleMoveFileResponse(response, data: data, error: error))
        }
        .resume()
    }
    
    func delete(operation: BackupWebDAVOperationDELETE, completion: @escaping (Result<Void, BackupWebDAVResponseError>) -> Void) {
        guard let config, let url = operation.url(for: config.normalizedURL, vid: config.vid) else {
            completion(.failure(.generalError))
            return
        }
        let request = requestsBuilder.buildRequest(of: .delete(
            url: url,
            login: config.login,
            password: config.password
        ))
        session?.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            completion(responseHandler.handleDeleteFileResponse(response, data: data, error: error))
        }
        .resume()
    }
}

private final class SessionDelegate: NSObject, URLSessionDelegate {
    private var login: String?
    private var password: String?
    private var allowTLSOff: Bool = false
    
    func setCredentials(allowTLSOff: Bool, login: String?, password: String?) {
        self.allowTLSOff = allowTLSOff
        self.login = login
        self.password = password
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            if let login, let password {
                let credential = URLCredential(
                    user: login,
                    password: password,
                    persistence: .forSession
                )
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.useCredential, nil)
            }
            return
        }
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        if allowTLSOff {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            var error: CFError?
            let isValid = SecTrustEvaluateWithError(serverTrust, &error)
            
            if isValid {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                Log("TLS certificate validation failed: \(error?.localizedDescription ?? "Unknown error")", module: .backup, severity: .error)
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
}
