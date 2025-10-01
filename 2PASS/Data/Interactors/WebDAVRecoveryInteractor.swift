// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

public enum WebDAVRecoveryInteractorError: Error {
    case indexIsDamaged
    case vaultIsDamaged
    case unauthorized
    case forbidden
    case methodNotAllowed
    case indexNotFound
    case vaultNotFound
    case nothingToImport
    case schemaNotSupported(Int)
    case sslError
    case syncError(message: String?)
    case networkError(message: String)
    case serverError(message: String)
    case urlError(message: String)
}

public protocol WebDAVRecoveryInteracting: AnyObject {
    func recover(
        baseURL: String,
        normalizedURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        completion: @escaping (Result<WebDAVIndex, WebDAVRecoveryInteractorError>) -> Void
    )
    func fetchVault(
        baseURL: URL,
        allowTLSOff: Bool,
        vaultID: VaultID,
        schemeVersion: Int,
        login: String?,
        password: String?,
        completion: @escaping (Result<ExchangeVault, WebDAVRecoveryInteractorError>) -> Void
    )
    func saveConfiguration(baseURL: URL, allowTLSOff: Bool, vaultID: VaultID, login: String?, password: String?)
    func resetConfiguration()
}

final class WebDAVRecoveryInteractor {
    private let mainRepository: MainRepository
    private let backupImportInteractor: BackupImportInteracting
    
    private var shouldStop = false
    private var fetchedIndex: WebDAVIndex?
    
    init(
        mainRepository: MainRepository,
        backupImportInteractor: BackupImportInteracting,
    ) {
        self.mainRepository = mainRepository
        self.backupImportInteractor = backupImportInteractor
    }
}

extension WebDAVRecoveryInteractor: WebDAVRecoveryInteracting {

    func recover(
        baseURL: String,
        normalizedURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        completion: @escaping (Result<WebDAVIndex, WebDAVRecoveryInteractorError>) -> Void
    ) {
        mainRepository.webDAVSetBackupConfig(
            .init(baseURL: baseURL,
            normalizedURL: normalizedURL,
            allowTLSOff: allowTLSOff,
            login: login,
            password: password)
        )
        Log("WebDAVRecoveryInteractor - starting recovery", module: .interactor)
        
        mainRepository.webDAVGetIndex { [weak self] result in
            switch result {
            case .success(let index):
                guard let index = self?.mainRepository.webDAVDecodeIndex(index) else {
                    Log("WebDAVRecoveryInteractor - index damaged", module: .interactor)
                    completion(.failure(.indexIsDamaged))
                    return
                }
                Log("WebDAVRecoveryInteractor - getting index success, parsing", module: .interactor)
                completion(.success(index))
            case .failure(let error):
                switch error {
                case .unauthorized:
                    Log("WebDAVRecoveryInteractor - getting index error: unauthorized", module: .interactor, severity: .error)
                    completion(.failure(.unauthorized))
                case .forbidden:
                    Log("WebDAVRecoveryInteractor - getting index error: forbidden", module: .interactor, severity: .error)
                    completion(.failure(.forbidden))
                case .syncErrorTryingAgain:
                    Log("WebDAVRecoveryInteractor - getting index error: sync error", module: .interactor, severity: .error)
                    completion(.failure(.syncError(message: nil)))
                case .notFound:
                    Log("WebDAVRecoveryInteractor - no index. Setting lock", module: .interactor)
                    completion(.failure(.indexNotFound))
                case .syncError(let error):
                    Log("WebDAVRecoveryInteractor - getting index error: sync error: \(error)", module: .interactor, severity: .error)
                    completion(.failure(.syncError(message: error.localizedDescription)))
                case .networkError(let error):
                    Log("WebDAVRecoveryInteractor - getting index error: network error: \(error)", module: .interactor, severity: .error)
                    completion(.failure(.networkError(message: error.localizedDescription)))
                case .serverError(let error):
                    Log("WebDAVRecoveryInteractor - getting index error: server error: \(error)", module: .interactor, severity: .error)
                    completion(.failure(.serverError(message: error.localizedDescription)))
                case .urlError(let error):
                    Log("WebDAVRecoveryInteractor - getting index error: incorrect url: \(error)", module: .interactor, severity: .error)
                    completion(.failure(.urlError(message: error.localizedDescription)))
                case .sslError:
                    Log("WebDAVRecoveryInteractor - getting index error: SSL error)", module: .interactor, severity: .error)
                    completion(.failure(.sslError))
                case .methodNotAllowed:
                    Log("WebDAVRecoveryInteractor - getting index error: method not allowed", module: .interactor, severity: .error)
                    completion(.failure(.methodNotAllowed))
                }
            }
        }
    }
    
    func fetchVault(
        baseURL: URL,
        allowTLSOff: Bool,
        vaultID: VaultID,
        schemeVersion: Int,
        login: String?,
        password: String?,
        completion: @escaping (Result<ExchangeVault, WebDAVRecoveryInteractorError>) -> Void
    ) { 
        Log("WebDAVRecoveryInteractor - fetching Vault with scheme version: \(schemeVersion)", module: .interactor)
        
        // Check if the scheme version is supported before fetching
        if schemeVersion > Config.schemaVersion {
            Log("WebDAVRecoveryInteractor - scheme version \(schemeVersion) not supported, expected \(Config.schemaVersion) or lower", module: .interactor, severity: .error)
            completion(.failure(.schemaNotSupported(schemeVersion)))
            return
        }
        
        mainRepository.webDAVSetBackupConfig(
            .init(baseURL: baseURL.absoluteString,
                  normalizedURL: baseURL,
                  lockTime: Config.webDAVLockFileTime,
                  allowTLSOff: allowTLSOff,
                  vid: vaultID.uuidString,
                  login: login,
                  password: password)
        )
        mainRepository.webDAVGetVault { [weak self] result in
            switch result {
            case .success(let vaultData):
                Log("WebDAVRecoveryInteractor - Vault fetched. Parsing", module: .interactor)
                self?.backupImportInteractor.parseRaw(data: vaultData) { parseResult in
                    switch parseResult {
                    case .success(let exchangeVault):
                        completion(.success(exchangeVault))
                    case .failure(let parseError):
                        switch parseError {
                        case .jsonError(let error):
                            Log("WebDAVRecoveryInteractor - error, Vault file corrupted: \(error)", module: .interactor, severity: .error)
                            completion(.failure(.vaultIsDamaged))
                        case .nothingToImport:
                            Log("WebDAVRecoveryInteractor - nothing to import", module: .interactor)
                            completion(.failure(.nothingToImport))
                        case .schemaNotSupported(let actualVersion):
                            Log("WebDAVRecoveryInteractor - schema not supported: version \(actualVersion)", module: .interactor)
                            completion(.failure(.schemaNotSupported(actualVersion)))
                        }
                    }
                }
            case .failure(let error):
                switch error {
                case .unauthorized:
                    Log("WebDAVRecoveryInteractor - fetching Vault error: unauthorized", module: .interactor, severity: .error)
                    completion(.failure(.unauthorized))
                case .forbidden:
                    Log("WebDAVRecoveryInteractor - fetching Vault error: forbidden", module: .interactor, severity: .error)
                    completion(.failure(.forbidden))
                case .syncErrorTryingAgain:
                    Log("WebDAVRecoveryInteractor - fetching Vault error: sync error", module: .interactor, severity: .error)
                    completion(.failure(.syncError(message: nil)))
                case .notFound:
                    Log("WebDAVRecoveryInteractor - no Vault found. Creating", module: .interactor)
                    completion(.failure(.vaultNotFound))
                case .syncError(let error):
                    Log("WebDAVRecoveryInteractor - fetching Vault error: sync error \(error)", module: .interactor, severity: .error)
                    completion(.failure(.syncError(message: error.localizedDescription)))
                case .networkError(let error):
                    Log("WebDAVRecoveryInteractor - fetching Vault error: network error \(error)", module: .interactor, severity: .error)
                    completion(.failure(.networkError(message: error.localizedDescription)))
                case .serverError(let error):
                    Log("WebDAVRecoveryInteractor - fetching Vault error: server error \(error)", module: .interactor, severity: .error)
                    completion(.failure(.serverError(message: error.localizedDescription)))
                case .urlError(let error):
                    Log("WebDAVRecoveryInteractor - fetching Vault error: incorrect url: \(error)", module: .interactor, severity: .error)
                    completion(.failure(.urlError(message: error.localizedDescription)))
                case .sslError:
                    Log("WebDAVRecoveryInteractor - fetching Vault error: SSL error)", module: .interactor, severity: .error)
                    completion(.failure(.sslError))
                case .methodNotAllowed:
                    Log("WebDAVRecoveryInteractor - getting index error: method not allowed", module: .interactor, severity: .error)
                    completion(.failure(.methodNotAllowed))
                }
            }
        }
    }
    
    func saveConfiguration(baseURL: URL, allowTLSOff: Bool, vaultID: VaultID, login: String?, password: String?) {        
        mainRepository.webDAVSaveSavedConfig(
            .init(
                baseURL: baseURL.absoluteString,
                normalizedURL: baseURL,
                lockTime: Config.webDAVLockFileTime,
                allowTLSOff: allowTLSOff,
                vid: vaultID.uuidString,
                login: login,
                password: password
            )
        )
        mainRepository.webDAVSetIsConnected(true)
    }
    
    func resetConfiguration() {
        mainRepository.webDAVClearConfig()
        mainRepository.webDAVClearIsConnected()
    }
}
