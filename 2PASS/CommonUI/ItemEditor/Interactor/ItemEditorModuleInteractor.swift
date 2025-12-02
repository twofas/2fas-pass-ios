// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

public typealias SaveItemResult = Result<SaveItemSuccess, SaveItemError>

public enum SaveItemSuccess {
    case saved(ItemID)
    case deleted(ItemID)
    
    public var itemID: ItemID {
        switch self {
        case .saved(let itemID):
            return itemID
        case .deleted(let itemID):
            return itemID
        }
    }
}

public enum SaveItemError: Error {
    case userCancelled
    case uriNormalizationFailed
    case interactorError(ItemsInteractorSaveError)
}

enum ItemEditorModuleInteractorCheckState {
    case noChange
    case deleted
    case edited
}

protocol ItemEditorModuleInteracting: AnyObject {
    var hasItems: Bool { get }

    var changeRequest: (any ItemDataChangeRequest)? { get }

    var currentDefaultProtectionLevel: ItemProtectionLevel { get }

    func getEditItem() -> ItemData?
    func getTags(for tagIds: [ItemTagID]) -> [ItemTagData]

    func saveLogin(
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        iconType: PasswordIconType,
        protectionLevel: ItemProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> SaveItemResult

    func saveSecureNote(
        name: String?,
        text: String?,
        additionalInfo: String?,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> SaveItemResult

    func savePaymentCard(
        name: String?,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> SaveItemResult

    func decryptSecureField(_ data: Data, protectionLevel: ItemProtectionLevel) -> String?
    func detectPaymentCardIssuer(from cardNumber: String?) -> PaymentCardIssuer?
    func maxCardNumberLength(for issuer: PaymentCardIssuer?) -> Int
    func maxSecurityCodeLength(for issuer: PaymentCardIssuer?) -> Int

    func mostUsedUsernames() -> [String]
    func normalizeURLString(_ str: String) -> String?
    func extractDomain(from urlString: String) -> String?
    func generatePassword() -> String
    func fetchIconImage(from url: URL) async throws -> Data
    func checkCurrentPasswordState() -> ItemEditorModuleInteractorCheckState
    func moveToTrash() -> ItemID?
}

final class ItemEditorModuleInteractor {
    public let changeRequest: (any ItemDataChangeRequest)?

    private let itemsInteractor: ItemsInteracting
    private let loginItemInteractor: LoginItemInteracting
    private let secureNoteItemInteractor: SecureNoteItemInteracting
    private let paymentCardItemInteractor: PaymentCardItemInteracting
    private let configInteractor: ConfigInteracting
    private let uriInteractor: URIInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    private let passwordGeneratorInteractor: PasswordGeneratorInteracting
    private let fileIconInteractor: FileIconInteracting
    private let currentDateInteractor: CurrentDateInteracting
    private let passwordListInteractor: PasswordListInteracting
    private let tagInteractor: TagInteracting
    private let editItemID: ItemID?

    private var modificationDate: Date?

    init(
        itemsInteractor: ItemsInteracting,
        loginItemInteractor: LoginItemInteracting,
        secureNoteItemInteractor: SecureNoteItemInteracting,
        paymentCardItemInteractor: PaymentCardItemInteracting,
        configInteractor: ConfigInteracting,
        uriInteractor: URIInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting,
        autoFillCredentialsInteractor: AutoFillCredentialsInteracting,
        passwordGeneratorInteractor: PasswordGeneratorInteracting,
        fileIconInteractor: FileIconInteracting,
        currentDateInteractor: CurrentDateInteracting,
        passwordListInteractor: PasswordListInteracting,
        tagInteractor: TagInteracting,
        editItemID: ItemID?,
        changeRequest: (any ItemDataChangeRequest)? = nil
    ) {
        self.itemsInteractor = itemsInteractor
        self.loginItemInteractor = loginItemInteractor
        self.secureNoteItemInteractor = secureNoteItemInteractor
        self.paymentCardItemInteractor = paymentCardItemInteractor
        self.configInteractor = configInteractor
        self.uriInteractor = uriInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
        self.autoFillCredentialsInteractor = autoFillCredentialsInteractor
        self.passwordGeneratorInteractor = passwordGeneratorInteractor
        self.fileIconInteractor = fileIconInteractor
        self.currentDateInteractor = currentDateInteractor
        self.passwordListInteractor = passwordListInteractor
        self.tagInteractor = tagInteractor
        self.editItemID = editItemID
        self.changeRequest = changeRequest
    }
}

extension ItemEditorModuleInteractor: ItemEditorModuleInteracting {
        
    var hasItems: Bool {
        itemsInteractor.hasItems
    }
    
    var currentDefaultProtectionLevel: ItemProtectionLevel {
        configInteractor.currentDefaultProtectionLevel
    }
    
    func getEditItem() -> ItemData? {
        guard let editItemID else {
            return nil
        }
        let item = itemsInteractor.getItem(for: editItemID, checkInTrash: false)
        modificationDate = item?.modificationDate
        return item
    }
    
    func decryptSecureField(_ data: Data, protectionLevel: ItemProtectionLevel) -> String? {
        itemsInteractor.decrypt(data, isSecureField: true, protectionLevel: protectionLevel)
    }

    func detectPaymentCardIssuer(from cardNumber: String?) -> PaymentCardIssuer? {
        paymentCardItemInteractor.detectCardIssuer(from: cardNumber)
    }

    func maxCardNumberLength(for issuer: PaymentCardIssuer?) -> Int {
        paymentCardItemInteractor.maxCardNumberLength(for: issuer)
    }

    func maxSecurityCodeLength(for issuer: PaymentCardIssuer?) -> Int {
        paymentCardItemInteractor.maxSecurityCodeLength(for: issuer)
    }

    func getTags(for tagIds: [ItemTagID]) -> [ItemTagData] {
        tagInteractor.getTags(by: tagIds).sorted(by: { $0.name < $1.name })
    }
    
    func saveLogin(
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        iconType: PasswordIconType,
        protectionLevel: ItemProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> SaveItemResult {
        let date = currentDateInteractor.currentDate
        if let current = getEditItem()?.asLoginItem {
            do {
                try loginItemInteractor.updateLogin(
                    id: current.id,
                    metadata: .init(
                        creationDate: current.creationDate,
                        modificationDate: date,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: tagIds ?? current.tagIds
                    ),
                    name: name,
                    username: username,
                    password: password,
                    notes: notes,
                    iconType: iconType,
                    uris: uris
                )
                
                Log("ItemEditorModuleInteractor - success while updating password. Saving storage")
                didSaveItem()
                
                Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                    try await autoFillCredentialsInteractor.replaceSuggestions(
                        from: current,
                        itemID: current.id,
                        username: username,
                        uris: uris,
                        protectionLevel: protectionLevel
                    )
                }
                
                return .success(.saved(current.id))
                
            } catch {
                return .failure(.interactorError(error))
            }
        } else {
            let itemID = UUID()
            do {
                try loginItemInteractor.createLogin(
                    id: itemID,
                    metadata: .init(
                        creationDate: date,
                        modificationDate: date,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: tagIds
                    ),
                    name: name,
                    username: username,
                    password: password,
                    notes: notes,
                    iconType: iconType,
                    uris: uris
                )
                
                Log("ItemEditorModuleInteractor - success while adding password. Saving storage")
                
                didSaveItem()
            
                Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                    try await autoFillCredentialsInteractor.addSuggestions(
                        itemID: itemID,
                        username: username,
                        uris: uris,
                        protectionLevel: protectionLevel
                    )
                }
                
                return .success(.saved(itemID))
                
            } catch {
                return .failure(.interactorError(error))
            }
        }
    }

    func saveSecureNote(
        name: String?,
        text: String?,
        additionalInfo: String?,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> SaveItemResult {
        let date = currentDateInteractor.currentDate
        if let current = getEditItem()?.asSecureNote {
            do {
                try secureNoteItemInteractor.updateSecureNote(
                    id: current.id,
                    metadata: .init(
                        creationDate: current.creationDate,
                        modificationDate: date,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: tagIds ?? current.tagIds
                    ),
                    name: name ?? "",
                    text: text,
                    additionalInfo: additionalInfo
                )

                Log("ItemEditorModuleInteractor - success while updating secure note. Saving storage")
                didSaveItem()

                return .success(.saved(current.id))

            } catch {
                return .failure(.interactorError(error))
            }
        } else {
            let itemID = UUID()
            do {
                try secureNoteItemInteractor.createSecureNote(
                    id: itemID,
                    metadata: .init(
                        creationDate: date,
                        modificationDate: date,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: tagIds
                    ),
                    name: name ?? "",
                    text: text,
                    additionalInfo: additionalInfo
                )

                Log("ItemEditorModuleInteractor - success while adding secure note. Saving storage")
                didSaveItem()

                return .success(.saved(itemID))

            } catch {
                return .failure(.interactorError(error))
            }
        }
    }

    func savePaymentCard(
        name: String?,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> SaveItemResult {
        let date = currentDateInteractor.currentDate
        if let current = getEditItem()?.asPaymentCard {
            do {
                try paymentCardItemInteractor.updatePaymentCard(
                    id: current.id,
                    metadata: .init(
                        creationDate: current.creationDate,
                        modificationDate: date,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: tagIds ?? current.tagIds
                    ),
                    name: name ?? "",
                    cardHolder: cardHolder,
                    cardNumber: cardNumber,
                    expirationDate: expirationDate,
                    securityCode: securityCode,
                    notes: notes
                )

                Log("ItemEditorModuleInteractor - success while updating payment card. Saving storage")
                didSaveItem()

                return .success(.saved(current.id))

            } catch {
                return .failure(.interactorError(error))
            }
        } else {
            let itemID = UUID()
            do {
                try paymentCardItemInteractor.createPaymentCard(
                    id: itemID,
                    metadata: .init(
                        creationDate: date,
                        modificationDate: date,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: tagIds
                    ),
                    name: name ?? "",
                    cardHolder: cardHolder,
                    cardNumber: cardNumber,
                    expirationDate: expirationDate,
                    securityCode: securityCode,
                    notes: notes
                )

                Log("ItemEditorModuleInteractor - success while adding payment card. Saving storage")
                didSaveItem()

                return .success(.saved(itemID))

            } catch {
                return .failure(.interactorError(error))
            }
        }
    }

    func mostUsedUsernames() -> [String] {
        passwordListInteractor.mostUsedUsernames()
    }
    
    func normalizeURLString(_ str: String) -> String? {
        uriInteractor.normalize(str)
    }
    
    func extractDomain(from urlString: String) -> String? {
        uriInteractor.extractDomain(from: urlString)
    }
    
    func generatePassword() -> String {
        let config = configInteractor.passwordGeneratorConfig ?? .init(length: passwordGeneratorInteractor.prefersPasswordLength, hasDigits: true, hasUppercase: true, hasSpecial: true)
        return passwordGeneratorInteractor.generatePassword(using: config)
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
    
    func checkCurrentPasswordState() -> ItemEditorModuleInteractorCheckState {
        guard let editItemID, let modificationDate else { return .noChange }
        guard let pass = itemsInteractor.getItem(for: editItemID, checkInTrash: false) else {
            return .deleted
        }
        if pass.modificationDate.isAfter(modificationDate) {
            return .edited
        }
        return .noChange
    }
    
    func moveToTrash() -> ItemID? {
        guard let editItemID else {
            return nil
        }
        itemsInteractor.markAsTrashed(for: editItemID)
        itemsInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
        return editItemID
    }
    
    private func didSaveItem() {
        itemsInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
}
