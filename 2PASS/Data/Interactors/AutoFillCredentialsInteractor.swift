// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import AuthenticationServices

public protocol AutoFillCredentialsInteracting: AnyObject {
    func canAddSuggestionForPassword(with level: ItemProtectionLevel) -> Bool
    
    func addSuggestions(passwordID: PasswordID, username: String?, uris: [PasswordURI]?, protectionLevel: ItemProtectionLevel) async throws
    func replaceSuggestions(from passwordData: PasswordData, passwordID: PasswordID, username: String?, uris: [PasswordURI]?, protectionLevel: ItemProtectionLevel) async throws
    func removeSuggestions(for passwordData: PasswordData) async throws
    
    func syncSuggestions() async throws
}

final class AutoFillCredentialsInteractor: AutoFillCredentialsInteracting {
        
    private let mainRepository: MainRepository
    private let uriInteractor: URIInteracting
    private let store = ASCredentialIdentityStore.shared
    
    init(mainRepository: MainRepository, uriInteractor: URIInteracting) {
        self.mainRepository = mainRepository
        self.uriInteractor = uriInteractor
    }
    
    func canAddSuggestionForPassword(with protectionLevel: ItemProtectionLevel) -> Bool {
        Config.autoFillExcludeProtectionLevels.contains(protectionLevel) == false
    }
    
    func addSuggestions(passwordID: PasswordID, username: String?, uris: [PasswordURI]?, protectionLevel: ItemProtectionLevel) async throws {
        let isEnabled = await mainRepository.refreshAutoFillStatus()
        guard isEnabled else {
            return
        }
        
        guard canAddSuggestionForPassword(with: protectionLevel) else { return }
        guard let uris else { return }

        Log("Autofill - Start add suggestions", module: .autofill)
        do {
            try await store.saveCredentialIdentities(
                uris.compactMap { uri in
                    guard Config.allowsMatchRulesForSuggestions.contains(uri.match) else { return nil }
                    guard let uriNormalized = uriInteractor.normalize(uri.uri) else { return nil }
                    return ASPasswordCredentialIdentity(
                        serviceIdentifier: .init(identifier: uriNormalized, type: .URL),
                        user: username ?? "",
                        recordIdentifier: passwordID.uuidString
                    )
                } as [any ASCredentialIdentity]
            )
            Log("Autofill - Add suggestions completed", module: .autofill)
        } catch {
            Log("Autofill = Add suggestions failure: \(error)", module: .autofill)
        }
    }
    
    func replaceSuggestions(from oldPasswordData: PasswordData, passwordID: PasswordID, username: String?, uris: [PasswordURI]?, protectionLevel: ItemProtectionLevel) async throws {
        try await removeSuggestions(for: oldPasswordData)
        try await addSuggestions(passwordID: passwordID, username: username, uris: uris, protectionLevel: protectionLevel)
    }
    
    func removeSuggestions(for passwordData: PasswordData) async throws {
        if let uris = passwordData.uris {
            Log("Autofill - Start remove suggestions", module: .autofill)
            do {
                try await store.removeCredentialIdentities(
                    uris.compactMap { uri in
                        guard let uriNormalized = uriInteractor.normalize(uri.uri) else { return nil }
                        return ASPasswordCredentialIdentity(
                            serviceIdentifier: .init(identifier: uriNormalized, type: .URL),
                            user: passwordData.username ?? "",
                            recordIdentifier: passwordData.id.uuidString
                        )
                    } as [any ASCredentialIdentity]
                )
                Log("Autofill - Remove suggestions completed", module: .autofill)
            } catch {
                Log("Autofill = Remove suggestions failure: \(error)", module: .autofill)
            }
        }
    }
    
    func syncSuggestions() async throws { // TODO: Naive implementation. Should migrate to incremental updates.
        let isEnabled = await mainRepository.refreshAutoFillStatus()
        guard isEnabled else {
            return
        }
        
        let startDate = Date()
        Log("Autofill - Start sync suggestions", module: .autofill)
        
        let passwords = Task { @MainActor in
            mainRepository.listPasswords(options: .allNotTrashed).filter {
                canAddSuggestionForPassword(with: $0.protectionLevel)
            }
        }
        
        let credentials = makeCredentialIdentities(for: await passwords.value)
        do {
            try await store.replaceCredentialIdentities(credentials)
            Log("Autofill - Sync suggestions completed", module: .autofill)
        } catch {
            Log("Autofill - Sync suggestions failure: \(error)", module: .autofill)
        }
        
        let time = Date().timeIntervalSince(startDate)
        Log("Autofill - Sync time: \(time)", module: .autofill)
    }
    
    private func makeCredentialIdentities(for passwords: [PasswordData]) -> [ASPasswordCredentialIdentity] {
        passwords.flatMap { password in
            password.uris?.compactMap { uri in
                guard Config.allowsMatchRulesForSuggestions.contains(uri.match) else { return nil }
                guard let uriNormalized = uriInteractor.normalize(uri.uri) else { return nil }

                return ASPasswordCredentialIdentity(
                    serviceIdentifier: .init(identifier: uriNormalized, type: .URL),
                    user: password.username ?? "",
                    recordIdentifier: password.id.uuidString
                )
            } ?? []
        }
    }
}
