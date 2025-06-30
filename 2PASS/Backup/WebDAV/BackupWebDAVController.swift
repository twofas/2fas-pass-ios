// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum BackupWebDAVSyncError: Error {
    case unauthorized
    case forbidden
    case syncErrorTryingAgain
    case notFound
    case sslError
    case methodNotAllowed
    case syncError(Error)
    case networkError(Error)
    case serverError(Error)
    case urlError(Error)
}

public final class BackupWebDAVController {
    private let connection = BackupWebDAVConnection()
    
    private var config: BackupWebDAVConfig?
    
    public init() {}
    
    public func setConfig(_ config: BackupWebDAVConfig) {
        self.config = config
        connection.setConnectionConfig(config)
    }
}

public extension BackupWebDAVController {
    func getIndex(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        connection.get(operation: .index) { [weak self] result in
            self?.getResponse(result: result, completion: completion)
        }
    }
     
    func getLock(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        connection.get(operation: .indexLock) { [weak self] result in
            self?.getResponse(result: result, completion: completion)
        }
    }
    
    func getVault(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        connection.get(operation: .vid) { [weak self] result in
            self?.getResponse(result: result, completion: completion)
        }
    }
    
    func writeIndex(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        connection.put(operation: .index, fileContents: fileContents) { [weak self] result in
            self?.voidResponse(result: result, completion: completion)
        }
    }
    
    func writeLock(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        connection.put(operation: .indexLock, fileContents: fileContents) { [weak self] result in
            self?.voidResponse(result: result, completion: completion)
        }
    }
    
    func writeVault(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        connection.put(operation: .vid, fileContents: fileContents) { [weak self] result in
            self?.voidResponse(result: result, completion: completion)
        }
    }
    
    func writeDecryptedVault(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        connection.put(operation: .decryptedVid, fileContents: fileContents) { [weak self] result in
            self?.voidResponse(result: result, completion: completion)
        }
    }
     
    func move(completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        connection.move(operation: .vid) { [weak self] result in
            self?.voidResponse(result: result, completion: completion)
        }
    }
    
    func delete(completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        connection.delete(operation: .indexLock) { [weak self] result in
            self?.voidResponse(result: result, completion: completion)
        }
    }
}

private extension BackupWebDAVController {
    func getResponse(
        result: Result<Data, BackupWebDAVResponseError>,
        completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void
    ) {
        switch result {
        case .success(let data):
            completion(.success(data))
        case .failure(let error):
            Log("BackupWebDAVController: GET response error: \(error)")
            completion(.failure(handleError(error)))
        }
    }
    
    func voidResponse(
        result: Result<Void,BackupWebDAVResponseError>,
        completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void
    ) {
        switch result {
        case .success(let data):
            completion(.success(data))
        case .failure(let error):
            Log("BackupWebDAVController: VOID response error: \(error)")
            completion(.failure(handleError(error)))
        }
    }
    
    func handleError(_ error: BackupWebDAVResponseError) -> BackupWebDAVSyncError {
        switch error {
        case .generalError,
                .incorrectResponse,
                .cantLock,
                .lockingPathOrNotLocked,
                .cantUnlock,
                .parseError,
                .alreadyLocked,
                .error: .syncErrorTryingAgain
        case .unauthorized: .unauthorized
        case .forbidden: .forbidden
        case .methodNotAllowed: .methodNotAllowed
        case .notFound: .notFound
        case .networkError(let netError): .networkError(netError)
        case .serverError(let serverError): .serverError(serverError)
        case .sslError: .sslError
        case .urlError(let urlError): .urlError(urlError)
        }
    }
}
