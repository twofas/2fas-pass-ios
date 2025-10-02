// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Security
import CryptoKit
import LocalAuthentication
import Backup
import Storage

enum HMACStringReturnType {
    case hex
    case base64
}

protocol MainRepository: AnyObject {
    
    var isMainAppProcess: Bool { get }
    
    // MARK: - AutoFill
    var isAutoFillEnabled: Bool { get }
    var didAutoFillStatusChanged: NotificationCenter.Notifications { get }
    @discardableResult func refreshAutoFillStatus() async -> Bool
    
    @MainActor @available(iOS 18, *)
    func requestAutoFillPermissions() async
    
    // MARK: - Push Notifications
    var isPushNotificationsEnabled: Bool { get }
    var didPushNotificationsStatusChanged: NotificationCenter.Notifications { get }
    @discardableResult func refreshPushNotificationsStatus() async -> Bool
    var canRequestPushNotificationsPermissions: Bool { get }
    func requestPushNotificationsPermissions() async
    
    var pushNotificationToken: String? { get }
    func savePushNotificationToken(_ token: String?)
    
    // MARK: - Security
    var isUserLoggedIn: Bool { get }
    var isAppInBackground: Bool { get }
    func setIsAppInBackground(_ isInBackground: Bool)
    
    var isOnboardingCompleted: Bool { get }
    func finishOnboarding()
    
    var isConnectOnboardingCompleted: Bool { get }
    func finishConnectOnboarding()
    
    var shouldShowQuickSetup: Bool { get }
    func setShouldShowQuickSetup(_ value: Bool)
    
    var lastAppUpdatePromptDate: Date? { get }
    func setLastAppUpdatePromptDate(_ date: Date)
    func clearLastAppUpdatePromptDate()
    
    var minimalAppVersionSupported: String? { get }
    func setMinimalAppVersionSupported(_ version: String)
    func clearMinimalAppVersionSupported()
    
    // MARK: - Biometry
    var biometryType: BiometryType { get }
    var isBiometryEnabled: Bool { get }
    var isBiometryAvailable: Bool { get }
    var isBiometryLockedOut: Bool { get }
    func disableBiometry()
    
    func reloadAuthContext()
    
    func saveBiometryFingerprint(_ data: Data)
    func clearBiometryFingerpring()
    var biometryFingerpring: Data? { get }
    
    func authenticateUsingBiometry(
        reason: String,
        completion: @escaping (BiometricAuthResult) -> Void
    )
    
    var requestedForBiometryToLogin: Bool { get }
    func setRequestedForBiometryToLogin(_ requested: Bool)
    
    // MARK: App lock
    var appLockAttempts: AppLockAttempts { get }
    func setAppLockAttempts(_ value: AppLockAttempts)

    var appLockBlockTime: AppLockBlockTime? { get }
    func setAppLockBlockTime(_ value: AppLockBlockTime)
    func clearAppLockBlockTime()
    
    var lockAppUntil: Date? { get }
    func setLockAppUntil(date: Date)
    func clearLockAppUntil()
    
    var incorrectLoginCountAttemp: Int { get }
    func setIncorrectLoginCountAttempt(_ count: Int)
    func clearIncorrectLoginCountAttempt()
    
    var incorrectBiometryCountAttemp: Int { get }
    func setIncorrectBiometryCountAttempt(_ count: Int)
    func clearIncorrectBiometryCountAttempt()
        
    // MARK: - General
    var currentAppVersion: String { get }
    var currentBuildVersion: String { get }
    var lastKnownAppVersion: String? { get }
    func setLastKnownAppVersion(_ version: String)
    func setCrashlyticsEnabled(_ enabled: Bool)
    var isCrashlyticsEnabled: Bool { get }
    
    func initialPermissionStateSetChildren(_ children: [PermissionsStateChildDataControllerProtocol])
    func initialPermissionStateInitialize()
    
    var appBundleIdentifier: String? { get }
    var dateOfFirstRun: Date? { get }
    func saveDateOfFirstRun(_ date: Date)
    
    func setActiveSearchEnabled(_ enabled: Bool)
    var isActiveSearchEnabled: Bool { get }
    
    var jsonEncoder: JSONEncoder { get }
    var jsonDecoder: JSONDecoder { get }
    
    var cloudSync: CloudSync { get }
    
    var deviceName: String { get }
    var deviceModelName: String { get }
    var systemVersion: String { get }
    
    func checkFileSize(for url: URL) -> Int?
    func readFileData(from url: URL) async -> Data?
    func fileExists(at url: URL) -> Bool
    func copyFileToLocalIfNeeded(from url: URL) -> URL?
    
    var is2FASAuthInstalled: Bool { get }
    
    // MARK: - Encryption
    var deviceID: UUID? { get }
    func saveDeviceID(_ deviceID: UUID)
    func clearDeviceID()
    func generateUUID() -> UUID
    
    func generateEntropy() -> Data?
    func createSeed(from entropy: Data) -> Seed
    func createCRC(from: Data) -> UInt8
    func create11BitPacks(from entropy: Data, seed: Data) -> [Int]
    func createWords(from bitPacks: [Int]) -> [String]?
    func createSalt(from words: [String]) -> Salt?
    
    func hmac(key: String, message: String) -> String?
    
    func normalizeStringIntoHEXData(_ string: String) -> String?
    func generateMasterKey(
        with masterPassword: String,
        seed: Seed,
        salt: Salt,
        kdfSpec: KDFSpec
    ) -> Data?
    var isSecureEnclaveAvailable: Bool { get }
    
    func createSecureEnclaveAccessControl(needAuth: Bool) -> SecAccessControl?
    func createSecureEnclavePrivateKey(
        accessControl: SecAccessControl,
        completion: @escaping (Data?) -> Void
    )
    func createSymmetricKeyFromSecureEnclave(from key: Data) -> SymmetricKey?
    func createSymmetricKey(from key: Data) -> SymmetricKey
    func getKey(isPassword: Bool, protectionLevel: ItemProtectionLevel) -> SymmetricKey?
    
    func encrypt(
        _ data: Data,
        key: SymmetricKey
    ) -> Data?
    func decrypt(
        _ data: Data,
        key: SymmetricKey
    ) -> Data?
    
    func encrypt(_ data: Data, key: SymmetricKey, nonce: Data) -> Data?
    func generateRandom(byteCount: Int) -> Data?
    
    func importBIP0039Words() -> [String]?
    func createSeedHashHexForExport() -> String?
    func createReferenceForExport() -> String?
    
    /// Used for Biometry, encrypted using Biometry Key
    var isMasterKeyStored: Bool { get }
    func decryptStoredMasterKey() -> MasterKeyEncrypted?
    func saveMasterKey(_ key: MasterKeyEncrypted)
    func clearMasterKey()
    
    var biometryKey: BiometryKey? { get }
    func saveBiometryKey(_ data: BiometryKey)
    func clearBiometryKey()
    
    /// Decrypted key from current Vault
    var trustedKeyFromVault: TrustedKey? { get }

    /// Generated on every app start, kept in memory
    var trustedKey: TrustedKey? { get }
    func setTrustedKey(_ data: TrustedKey)
    func clearTrustedKey()
    
    /// Generated on every app start, kept in memory
    var secureKey: SecureKey? { get }
    func setSecureKey(_ data: SecureKey)
    func clearSecureKey()
    
    /// Generated on every app start, kept in memory
    var externalKey: ExternalKey? { get }
    func setExternalKey(_ data: ExternalKey)
    func clearExternalKey()
    var cachedExternalKey: SymmetricKey? { get }
    
    /// Generated on first start
    var appKey: AppKey? { get }
    func saveAppKey(_ data: AppKey)
    func clearAppKey()
    
    /// Empheral storage
    var seed: Seed? { get }
    func setSeed(_ data: Seed)
    func clearSeed()
    
    var entropy: Entropy? { get }
    func setEntropy(_ entropy: Entropy)
    func clearEntropy()
    
    var words: [String]? { get }
    func setWords(_ words: [String])
    func clearWords()
    
    var salt: Data? { get }
    func setSalt(_ salt: Data)
    func clearSalt()
    
    var masterPassword: MasterPassword? { get }
    func setMasterPassword(_ masterPassword: MasterPassword)
    func clearMasterPassword()
    
    var empheralMasterKey: MasterKey? { get }
    func setEmpheralMasterKey(_ masterKey: MasterKey)
    func clearEmpheralMasterKey()
    
    func clearAllEmphemeral()
    
    func hasCachedKeys() -> Bool
    func preparedCachedKeys()
    
    /// Used for veryfiying the Master Key
    var hasEncryptionReference: Bool { get }
    func saveEncryptionReference(_ deviceID: DeviceID, masterKey: MasterKey)
    func verifyEncryptionReference(using masterKey: MasterKey, with deviceID: DeviceID) -> Bool
    func clearEncryptionReference()
    
    var hasMasterKeyEntropy: Bool { get }
    var masterKeyEntropy: Entropy? { get }
    func saveMasterKeyEntropy(_ string: Entropy)
    func clearMasterKeyEntropy()
    
    func generateTrustedKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String?
    func generateSecureKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String?
    func generateExternalKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String?
    func generateExchangeSeedHash(_ vaultID: VaultID, using seed: Data) -> String?
    
    // Recovering Entropy
    func convertWordsToDecimal(_ words: [String]) -> [Int]?
    func create11BitPacks(from decimals: [Int]) -> [UInt16]
    func create4BitPacksFrom11BitPacks(_ data: [UInt16]) -> [UInt8]
    func convertWordsTo4BitPacksAndCRC(_ words: [String]) -> (bitPacks: Data, crc: UInt8)?
    
    // MARK: - Storage
    var storageError: ((String) -> Void)? { get set }
    
    // MARK: - In Memory
    // MARK: Password
    
    func createPassword(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    )
    func updatePassword(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    )
    func updatePasswords(_ passwords: [PasswordData])
    func passwordsBatchUpdate(_ passwords: [PasswordData])
    func getPasswordEntity(
        passwordID: PasswordID,
        checkInTrash: Bool
    ) -> PasswordData?
    
    func listPasswords(
        options: PasswordListOptions
    ) -> [PasswordData]
    func listTrashedPasswords() -> [PasswordData]
    func deletePassword(passwordID: PasswordID)
    func deleteAllPasswords()
    func saveStorage()
    func listUsernames() -> [String]
    
    var hasInMemoryStorage: Bool { get }
    func createInMemoryStorage()
    func destroyInMemoryStorage()
    
    // MARK: Tags
    func createTag(_ tag: ItemTagData)
    func updateTag(_ tag: ItemTagData)
    func deleteTag(tagID: ItemTagID)
    func listTags(options: TagListOptions) -> [ItemTagData]
    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date)
    
    // MARK: - Encrypted Storage
    
    func saveEncryptedStorage()
    
    // MARK: Encrypted Items
    
    func createEncryptedItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    )
    func updateEncryptedItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    )
    func encryptedItemsBatchUpdate(_ items: [ItemEncryptedData])
    func getEncryptedItemEntity(itemID: ItemID) -> ItemEncryptedData?
    func listEncryptedItems(in vaultID: VaultID) -> [ItemEncryptedData]
    func listEncryptedItems(in vaultID: VaultID, excludeProtectionLevels: Set<ItemProtectionLevel>) -> [ItemEncryptedData]
    func addEncryptedItem(_ itemID: ItemID, to vaultID: VaultID)
    func deleteEncryptedItem(itemID: ItemID)
    func deleteAllEncryptedItems()
    
    func requiresReencryptionMigration() -> Bool
    func loadEncryptedStore(completion: @escaping Callback)
    func loadEncryptedStoreWithReencryptionMigration(completion: @escaping (Bool) -> Void)
    
    // MARK: Encrypted Vaults
    
    func listEncryptedVaults() -> [VaultEncryptedData]
    func getEncryptedVault(for vaultID: VaultID) -> VaultEncryptedData?
    func createEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    )
    func updateEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    )
    func deleteEncryptedVault(_ vaultID: VaultID)
    func selectVault(_ vaultID: VaultID)
    func clearVault()
    func deleteAllVaults()
    var selectedVault: VaultEncryptedData? { get }
    
    // MARK: Deleted Items
    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID)
    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID)
    func listDeletedItems(in vaultID: VaultID, limit: Int?) -> [DeletedItemData]
    func deleteDeletedItem(id: DeletedItemID)
   
    // MARK: - Web Browser
    func createEncryptedWebBrowser(_ data: WebBrowserEncryptedData)
    func updateEncryptedWebBrowser(_ data: WebBrowserEncryptedData)
    func deleteEncryptedWebBrowser(id: UUID)
    func listEncryptedWebBrowsers() -> [WebBrowserEncryptedData]
    
    // MARK: - Encrypted Tags
    func createEncryptedTag(_ tag: ItemTagEncryptedData)
    func updateEncryptedTag(_ tag: ItemTagEncryptedData)
    func deleteEncryptedTag(tagID: ItemTagID)
    func listEncryptedTags(in vault: VaultID) -> [ItemTagEncryptedData]
    func encryptedTagBatchUpdate(_ tags: [ItemTagEncryptedData], in vault: VaultID)
    func deleteAllEncryptedTags(in vault: VaultID)
    
    // MARK: - Sort
    var sortType: SortType? { get }
    func setSortType(_ sortType: SortType)
            
    // MARK: - Camera
    var permission: CameraPermissionState { get }
    var isCameraPresent: Bool { get }
    func checkForPermission() -> CameraPermissionState
    func requestPermission(result: @escaping (CameraPermissionState) -> Void)
    
    // MARK: - Cloud
    var isCloudBackupConnected: Bool { get }
    var cloudCurrentState: CloudState { get }
    func enableCloudBackup()
    func disableCloudBackup()
    func clearBackup()
    func synchronizeBackup()
    func cloudListVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void)
    func cloudDeleteVault(id: VaultID) async throws
    var lastSuccessCloudSyncDate: Date? { get }
    func setLastSuccessCloudSyncDate(_ date: Date)
    func clearLastSuccessCloudSyncDate()
    
    // MARK: - Cloud Cache
    func cloudCacheCreateItem(
        itemID: ItemID,
        content: Data,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        tagIds: [ItemTagID]?,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        metadata: Data
    )
    func cloudCacheUpdateItem(
        itemID: ItemID,
        content: Data,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        tagIds: [ItemTagID]?,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        metadata: Data
    )
    func cloudCacheGetItemEntity(itemID: ItemID) -> CloudDataItem?
    func cloudCacheListItems(in vaultID: VaultID) -> [CloudDataItem]
    func cloudCacheListAllItems() -> [CloudDataItem]
    func cloudCacheDeleteItem(itemID: ItemID)
    func cloudCacheDeleteAllItems()
    func cloudCacheListVaults() -> [VaultCloudData]
    func cloudCacheGetVault(for vaultID: VaultID) -> VaultCloudData?
    func cloudCacheCreateVault(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    )
    func cloudCacheUpdateVault(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    )
    func cloudCacheDeleteVault(_ vaultID: VaultID)
    func cloudCacheDeleteAllVaults()
    func cloudCacheCreateDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    )
    func cloudCacheUpdateDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    )
    func cloudCacheListDeletedItems(in vaultID: VaultID, limit: Int?) -> [CloudDataDeletedItem]
    func cloudCacheListAllDeletedItems(limit: Int?) -> [CloudDataDeletedItem]
    func cloudCacheDeleteDeletedItem(itemID: DeletedItemID)
    func cloudCacheDeleteAllDeletedItems()
    
    // MARK: - Cloud Cached Tags
    var cloudCacheIsInitializingNewStore: Bool { get }
    func cloudCacheMarkInitializingNewStoreAsHandled()
    func cloudCacheCreateTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    )
    func cloudCacheUpdateTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    )
    func cloudCacheGetTag(tagID: ItemTagID) -> CloudDataTagItem?
    func cloudCacheListTags(in vaultID: VaultID, limit: Int?) -> [CloudDataTagItem]
    func cloudCacheListAllTags(limit: Int?) -> [CloudDataTagItem]
    func cloudCacheDeleteTag(tagID: ItemTagID)
    func cloudCacheDeleteAllTags()
    
    func cloudCacheSave()
    
    // MARK: - System
    var syncHasError: Bool { get }
    func setSyncHasError(_ value: Bool)
    
    func copyToClipboard(_ str: String)
    func positiveFeedback()
    func negativeFeedback()
    func warningFeedback()
    
    // MARK: - Config
    var currentDefaultProtectionLevel: ItemProtectionLevel { get }
    func setDefaultProtectionLevel(_ value: ItemProtectionLevel)
    var passwordGeneratorConfig: Data? { get }
    func setPasswordGeneratorConfig(_ data: Data)
    var defaultPassswordListAction: PasswordListAction { get }
    func setDefaultPassswordListAction(_ action: PasswordListAction)
    
    // MARK: - Network
    func fetchFile(from url: URL, completion: @escaping (Result<Data, NetworkError>) -> Void)
    
    func cachedImage(from url: URL) -> Data?
    func fetchIconImage(from url: URL) async throws -> Data

    // MARK: - Image
    func resizeImage(from data: Data, to size: CGSize) -> Data?
    
    // MARK: - Logs
    func listAllLogs() -> [LogEntry]
    func removeAllLogs()
    func removeOldStoreLogs()
    
    // MARK: - WebDAV Backup
    func webDAVGetIndex(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void)
    func webDAVGetLock(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void)
    func webDAVGetVault(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void)
    func webDAVWriteIndex(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void)
    func webDAVWriteLock(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void)
    func webDAVWriteVault(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void)
    func webDAVWriteDecryptedVault(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void)
    func webDAVMove(completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void)
    func webDAVDeleteLock(completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void)
    func webDAVSetBackupConfig(_ config: BackupWebDAVConfig)
    var webDAVSavedConfig: BackupWebDAVConfig? { get }
    func webDAVSaveSavedConfig(_ config: BackupWebDAVConfig)
    func webDAVEncodeLock(timestamp: Int, deviceId: UUID) -> Data?
    func webDAVDecodeLock(_ data: Data) -> (timestamp: Int, deviceId: UUID)?
    func webDAVEncodeIndex(_ index: WebDAVIndex) -> Data?
    func webDAVDecodeIndex(_ data: Data) -> WebDAVIndex?
    func webDAVClearConfig()
    var webDAVSeedHash: String? { get }
    var webDAVCurrentVaultID: VaultID? { get }
    
    var webDAVIsConnected: Bool { get }
    func webDAVSetIsConnected(_ isConnected: Bool)
    func webDAVClearIsConnected()
    
    var webDAVHasLocalChanges: Bool { get }
    func webDAVSetHasLocalChanges()
    func webDAVClearHasLocalChanges()
    
    var webDAVState: WebDAVState { get }
    func webDAVSetState(_ state: WebDAVState)
    func webDAVClearState()
    
    var webDAVLastSync: WebDAVLock? { get }
    func webDAVSetLastSync(_ lastSync: WebDAVLock)
    func webDAVClearLastSync()
    
    var webDAVWriteDecryptedCopy: Bool { get }
    func webDAVSetWriteDecryptedCopy(_ writeDecryptedCopy: Bool)
    
    var webDAVAwaitsVaultOverrideAfterPasswordChange: Bool { get }
    func setWebDAVAwaitsVaultOverrideAfterPasswordChange(_ value: Bool)

    // MARK: 2FAS Web Service
    func appNotifications() async throws -> AppNotifications
    func deleteAppNotification(id: String) async throws
    
    // MARK: - Scan
    func scan(image: UIImage, completion: @escaping (Result<[String], ScanImageError>) -> Void)
    
    // MARK: - Time offset
    var timeOffset: TimeInterval { get }
    func setTimeOffset(_ offset: TimeInterval)
    func checkTimeOffset(completion: @escaping (TimeInterval?) -> Void)
    var currentDate: Date { get }
    
    // MARK: - Payment
    var paymentUserId: String? { get }
    var paymentSubscriptionPlan: SubscriptionPlan { get }
    func paymentInitialize(apiKey: String, debug: Bool)
    func paymentRegisterForUserUpdate(_ callback: @escaping () -> Void)
    func paymentRegisterForPromotedPurchase(_ callback: @escaping () -> Bool)
    func paymentUpdatePaymentStatus(subscriptionName: String)
    func paymentSubscriptionPrice(subscriptionName: String) async -> String?
    func paymentRunCachedPromotedPurchase()
    
    var isOverridedSubscriptionPlan: Bool { get }
    func overrideSubscriptionPlan(_ plan: SubscriptionPlan)
    func clearOverrideSubscriptionPlan()
    
    // MARK: - URI Cache
    func uriCacheSet(originalUri: String, parsedUri: String)
    func uriCacheGet(originalUri: String) -> String?
}
