// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

enum BackupWebDAVResponseError: Error, Equatable {
    static func == (lhs: BackupWebDAVResponseError, rhs: BackupWebDAVResponseError) -> Bool {
        switch (lhs, rhs) {
        case (.generalError, .generalError),
            (.incorrectResponse, .incorrectResponse),
            (.methodNotAllowed, .methodNotAllowed),
            (.unauthorized, .unauthorized),
            (.forbidden, .forbidden),
            (.notFound, .notFound),
            (.cantLock, .cantLock),
            (.lockingPathOrNotLocked, .lockingPathOrNotLocked),
            (.alreadyLocked, .alreadyLocked),
            (.cantUnlock, .cantUnlock),
            (.sslError, .sslError),
            (.error, .error),
            (.parseError, .parseError),
            (.networkError, .networkError),
            (.serverError, .serverError),
            (.urlError, .urlError):
            true
        default:
            false
        }
    }
    
    case generalError
    case incorrectResponse
    case methodNotAllowed
    case unauthorized
    case forbidden
    case notFound
    case cantLock
    case lockingPathOrNotLocked
    case alreadyLocked
    case cantUnlock
    case sslError
    case error(Error)
    case parseError(Error)
    case networkError(Error)
    case serverError(Error)
    case urlError(Error)
}

struct BackupWebDAVLockResponse {
    enum Timeout {
        case seconds(Int)
        case infinity
        case unknown
    }
    
    let token: String
    let timeout: Timeout
}

final class BackupWebDAVResponseHandler {
    func handleGetFileResponse(
        _ response: URLResponse?,
        data: Data?,
        error: (any Error)?
    ) -> Result<Data, BackupWebDAVResponseError> {
        if let error, let parsedError = parseError(error, hasData: data != nil) {
            Log("BackupWebDAVResponseHandler: GET file error: \(error)")
            return .failure(parsedError)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.generalError)
        }
        if let error = parseErrorCode(httpResponse.statusCode) {
            return .failure(error)
        }
        guard httpResponse.statusCode == 200, let data else {
            Log("BackupWebDAVResponseHandler: GET file incorrect status: \(httpResponse.statusCode)")
            return .failure(.incorrectResponse)
        }
        
        return .success(data)
    }
    
    func handleWriteFileResponse(
        _ response: URLResponse?,
        data: Data?,
        error: (any Error)?
    ) -> Result<Void, BackupWebDAVResponseError> {
        if let error, let parsedError = parseError(error, hasData: data != nil) {
            Log("BackupWebDAVResponseHandler: write file error: \(error)")
            return .failure(parsedError)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.generalError)
        }
        if let error = parseErrorCode(httpResponse.statusCode) {
            return .failure(error)
        }
        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 201 else {
            Log("BackupWebDAVResponseHandler: write file incorrect status: \(httpResponse.statusCode)")
            return .failure(.incorrectResponse)
        }
        
        return .success(())
    }
    
    func handleDeleteFileResponse(
        _ response: URLResponse?,
        data: Data?,
        error: (any Error)?
    ) -> Result<Void, BackupWebDAVResponseError> {
        if let error, let parsedError = parseError(error, hasData: data != nil) {
            Log("BackupWebDAVResponseHandler: DELETE file error: \(error)")
            return .failure(parsedError)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.generalError)
        }
        if let error = parseErrorCode(httpResponse.statusCode) {
            return .failure(error)
        }
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            Log("BackupWebDAVResponseHandler: DELETE file incorrect status: \(httpResponse.statusCode)")
            return .failure(.incorrectResponse)
        }
        
        return .success(())
    }
    
    func handleMoveFileResponse(
        _ response: URLResponse?,
        data: Data?,
        error: (any Error)?
    ) -> Result<Void, BackupWebDAVResponseError> {
        if let error, let parsedError = parseError(error, hasData: data != nil) {
            Log("BackupWebDAVResponseHandler: MOVE file error: \(error)")
            return .failure(parsedError)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.generalError)
        }
        if let error = parseErrorCode(httpResponse.statusCode) {
            return .failure(error)
        }
        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 204 else {
            Log("BackupWebDAVResponseHandler: MOVE file incorrect status: \(httpResponse.statusCode)")
            return .failure(.incorrectResponse)
        }
        
        return .success(())
    }
}

private extension BackupWebDAVResponseHandler {
    func parseError(_ error: any Error, hasData: Bool) -> BackupWebDAVResponseError? {
        let error = error as NSError
        if !hasData {
            if error.code.isSSLError {
                return .sslError
            } else if error.code.isUserAuthError {
                return .unauthorized
            } else if error.code.isNetworkError {
                return .networkError(error)
            } else if error.code.isServerError {
                return .serverError(error)
            } else if error.code.isURLError {
                return .urlError(error)
            } else {
                return .error(error)
            }
        }
        return nil
    }
    
    func parseErrorCode(_ code: Int) -> BackupWebDAVResponseError? {
        if code == 400 {
            return .generalError
        }
        if code == 401 {
            return .unauthorized
        }
        if code == 403 {
            return .forbidden
        }
        if code == 404 {
            return .notFound
        }
        if code == 405 {
            return .methodNotAllowed
        }
        if code == 409 {
            return .lockingPathOrNotLocked
        }
        if code == 412 {
            return .cantLock
        }
        if code == 423 {
            return .alreadyLocked
        }
        if code == 424 {
            return .cantUnlock
        }
        return nil
    }
    
    struct LockResponseXML: Codable, Equatable {
        struct Lockdiscovery: Codable, Equatable {
            struct Activelock: Codable, Equatable {
                struct Locktoken: Codable, Equatable {
                    let href: String
                }
                let locktoken: Locktoken
                let timeout: String
            }
            let activelock: Activelock
        }
        let lockdiscovery: Lockdiscovery
    }
}
