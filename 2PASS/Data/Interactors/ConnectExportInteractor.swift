// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CryptoKit
import Common

protocol ConnectExportInteracting: AnyObject {
    func preparePasswordForConnectExport(id: PasswordID, encryptPasswordKey: (PasswordProtectionLevel) -> SymmetricKey?, deviceId: UUID) async throws(ExportError) -> ConnectLogin
    func preparePasswordsForConnectExport(encryptPasswordKey: SymmetricKey, deviceId: UUID) async throws(ExportError) -> Data
    func prepareTagsForConnectExport() async throws(ExportError) -> Data
}

final class ConnectExportInteractor: ConnectExportInteracting {
    
    private let mainRepository: MainRepository
    private let passwordInteractor: PasswordInteracting
    private let uriInteractor: URIInteracting
    
    init(mainRepository: MainRepository, passwordInteractor: PasswordInteracting, uriInteractor: URIInteracting) {
        self.mainRepository = mainRepository
        self.passwordInteractor = passwordInteractor
        self.uriInteractor = uriInteractor
    }
    
    func preparePasswordsForConnectExport(encryptPasswordKey: SymmetricKey, deviceId: UUID) async throws(ExportError) -> Data {
        guard let _ = self.mainRepository.selectedVault else {
            throw .noSelectedVault
        }
        
        let passwords = Task { @MainActor in
            mainRepository.listPasswords(options: .allNotTrashed)
                .filter { $0.protectionLevel != .topSecret }
        }
             
        let connectLogins = await passwords.value.map {
            passwordToConnectLogin($0, deviceId: deviceId, excludePasswordsValueProtectionLevels: [.confirm], encryptPasswordKey: encryptPasswordKey)
        }
        
        do {
            return try self.mainRepository.jsonEncoder.encode(connectLogins)
        } catch {
            throw .jsonEncode(error: error)
        }
    }
    
    func preparePasswordForConnectExport(id: PasswordID, encryptPasswordKey: (PasswordProtectionLevel) -> SymmetricKey?, deviceId: UUID) async throws(ExportError) -> ConnectLogin {
        let password = Task { @MainActor in
            mainRepository.getPasswordEntity(passwordID: id, checkInTrash: false)
        }
        
        guard let entity = await password.value else {
            throw .noPasswordsToExport
        }
        
        let connectLogin = passwordToConnectLogin(entity, deviceId: deviceId, encryptPasswordKey: encryptPasswordKey(entity.protectionLevel))
        
        return connectLogin
    }
    
    func prepareTagsForConnectExport() async throws(ExportError) -> Data {
        let tags = passwordInteractor.listAllTags()
            .map {
                ConnectTag(
                    id: $0.id.uuidString,
                    name: $0.name,
                    color: $0.color?.hexString,
                    position: $0.position,
                    updatedAt: $0.modificationDate.exportTimestamp
                )
            }
        
        do {
            return try self.mainRepository.jsonEncoder.encode(tags)
        } catch {
            throw .jsonEncode(error: error)
        }
    }
    
    private func passwordToConnectLogin(
        _ password: PasswordData,
        deviceId: UUID,
        excludePasswordsValueProtectionLevels: Set<PasswordProtectionLevel> = [],
        encryptPasswordKey: SymmetricKey? = nil
    ) -> ConnectLogin {
        let passwordExported: String? = {
            guard excludePasswordsValueProtectionLevels.contains(password.protectionLevel) == false else {
                return nil
            }
            
            guard let pass = password.password else {
                return nil
            }
            
            guard let decryptedPassword = passwordInteractor.decrypt(pass, isPassword: true, protectionLevel: password.protectionLevel) else {
                return nil
            }
            
            if let encryptPasswordKey,
               let nonce = mainRepository.generateRandom(byteCount: Config.Connect.passwordNonceByteCount),
               let decryptedPasswordData = decryptedPassword.data(using: .utf8),
               let encrypted = mainRepository.encrypt(decryptedPasswordData, key: encryptPasswordKey, nonce: nonce) {
                return encrypted.base64EncodedString()
            } else {
                return nil
            }
        }()
        let securityType: Int = {
            switch password.protectionLevel {
            case .normal: 2
            case .confirm: 1
            case .topSecret: 0
            }
        }()
        var labelTitle: String?
        var labelColor: String?
        var customImageUrl: String?
        
        let iconType: Int = {
            switch password.iconType {
            case .domainIcon:
                return 0
            case .label(let labelTitleValue, let labelColorValue):
                labelTitle = labelTitleValue
                labelColor = labelColorValue?.hexString
                return 1
            case .customIcon(let iconURIValue):
                customImageUrl = iconURIValue.absoluteString
                return 2
            }
        }()
        
        let iconURIIndex: Int? = {
            switch password.iconType {
            case .domainIcon(let domain):
                return password.uris?.firstIndex(where: {
                    uriInteractor.extractDomain(from: $0.uri) == domain
                })
            default:
                return nil
            }
        }()
        
        return .init(
            id: password.passwordID.exportString(),
            name: password.name,
            username: password.username,
            password: passwordExported,
            notes: password.notes?.sanitizeNotes(),
            securityType: securityType,
            iconType: iconType,
            iconUriIndex: iconURIIndex,
            labelText: labelTitle,
            labelColor: labelColor,
            customImageUrl: customImageUrl,
            createdAt: password.creationDate.exportTimestamp,
            updatedAt: password.modificationDate.exportTimestamp,
            uris: password.uris?.map({ uriToConnectURI(uri: $0) }) ?? [],
            deviceId: deviceId
        )
    }
    
    private func uriToConnectURI(uri: PasswordURI) -> ConnectLogin.ConnectURI {
        let matcher: Int = {
            switch uri.match {
            case .domain: 0
            case .host: 1
            case .startsWith: 2
            case .exact: 3
            }
        }()
        return .init(text: uri.uri, matcher: matcher)
    }
}
