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

let ItemContentNameKey = "name"

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
    func sendPushNotification(_ text: String) async
    
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
    func migrateLegacyValuesToSharedDefaults()
    func setCrashlyticsEnabled(_ enabled: Bool)
    var isCrashlyticsEnabled: Bool { get }
    
    func initialPermissionStateSetChildren(_ children: [PermissionsStateChildDataControllerProtocol])
    func initialPermissionStateInitialize()
    
    var appBundleIdentifier: String? { get }
    var appDisplayName: String? { get }
    var dateOfFirstRun: Date? { get }
    func saveDateOfFirstRun(_ date: Date)
    
    func setActiveSearchEnabled(_ enabled: Bool)
    var isActiveSearchEnabled: Bool { get }
    
    var jsonEncoder: JSONEncoder { get }
    var jsonDecoder: JSONDecoder { get }

    var deviceName: String { get }
    func setDeviceName(_ name: String)
    var deviceModelName: String { get }
    var deviceType: DeviceType { get }
    var systemVersion: String { get }
    
    func checkFileSize(for url: URL) -> Int?
    func readFileData(from url: URL) async -> Data?
    func fileExists(at url: URL) -> Bool
    func copyFileToLocalIfNeeded(from url: URL) -> URL?
    func isDirectory(at url: URL) -> Bool?
    func readFilesFromFolder(at url: URL, withExtension ext: String, maxFileSize: Int) -> [String: Data]?
    func readLocalFile(at url: URL) -> Data?
    
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
    func encryptWithoutNonce(_ data: Data, key: SymmetricKey, nonce: Data) -> Data?
    func decrypt(_ data: Data, key: SymmetricKey, nonce: Data) -> Data?
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
    // MARK: Item
    
    func createItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    )

    func createLoginItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    )

    func createSecureNoteItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?,
        additionalInfo: String?
    )

    func createPaymentCardItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    )

    func createWiFiItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        ssid: String?,
        password: Data?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    )

    func updateMetadataItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int
    )
    
    func updateItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    )

    func updateLoginItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    )

    func updateSecureNoteItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?,
        additionalInfo: String?
    )

    func updatePaymentCardItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    )

    func updateWiFiItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        ssid: String?,
        password: Data?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    )

    func itemsBatchUpdate(_ items: [RawItemData])
    func metadataItemsBatchUpdate(_ items: [any ItemDataType])
    func getItemEntity(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> ItemData?
    
    func listItems(
        options: ItemsListOptions
    ) -> [ItemData]
    
    func listTrashedItems() -> [ItemData]
    func deleteItem(itemID: ItemID)
    func deleteAllItems()
    func saveStorage()
    func listUsernames() -> [String]

    var hasInMemoryStorage: Bool { get }
    func createInMemoryStorage()
    func destroyInMemoryStorage()

    func extractItemName(fromContent data: Data) -> String?
    
    // MARK: Tags
    func createTag(_ tag: ItemTagData)
    func updateTag(_ tag: ItemTagData)
    func deleteTag(tagID: ItemTagID)
    func deleteAllTags()
    func getTag(for tagID: ItemTagID) -> ItemTagData?
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
    func listEncryptedItems(
        in vaultID: VaultID,
        itemIDs: [ItemID]?,
        excludeProtectionLevels: Set<ItemProtectionLevel>?
    ) -> [ItemEncryptedData]
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
    func updateDeletedItems(_ items: [DeletedItemData])
    func deletedItem(id: DeletedItemID) -> DeletedItemData?
    func listDeletedItems(ids: Set<DeletedItemID>) -> [DeletedItemData]
    func listDeletedItems(in vaultID: VaultID, limit: Int?) -> [DeletedItemData]
    func deleteDeletedItem(id: DeletedItemID)
    func removeDuplicatedDeletedItems()

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
    func listAllEncryptedTags() -> [ItemTagEncryptedData]
    func encryptedTagBatchUpdate(_ tags: [ItemTagEncryptedData], in vault: VaultID)
    func deleteAllEncryptedTags(in vault: VaultID)
    func deleteAllEncryptedTags()
    
    // MARK: - Sort
    var sortType: SortType? { get }
    func setSortType(_ sortType: SortType)
            
    // MARK: - Camera
    var permission: CameraPermissionState { get }
    var isCameraPresent: Bool { get }
    func checkForPermission() -> CameraPermissionState
    func requestPermission(result: @escaping (CameraPermissionState) -> Void)
    
    // MARK: - Cloud
    func cloudListVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void)
    func cloudDeleteVault(id: VaultID) async throws
    
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
    var shareLinkConfig: Data? { get }
    func setShareLinkConfig(_ data: Data)
    var defaultPassswordListAction: PasswordListAction { get }
    func setDefaultPassswordListAction(_ action: PasswordListAction)
    var defaultURIMatchRule: PasswordURI.Match { get }
    func setDefaultURIMatchRule(_ rule: PasswordURI.Match)

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
    
    // MARK: - Backup Sync config persistence
    // Used by `BackupSyncAdapter` (the production `BackupSyncConfigStore`), which forwards 1:1.
    // These methods own the full persistence boundary: encryption with the Secure Enclave-derived
    // key, JSON encoding of `[BackupConfig]`, and UserDefaults blob storage. Callers deal only
    // in typed configs — they never see raw bytes or encryption.
    //
    // Returns an empty array on any failure (no configs persisted, decryption failed, decode
    // failed). Callers cannot distinguish "no entries" from "load failed"; that's deliberate
    // since both states present the same way to the user (no backends configured).
    func loadBackupConfigs() -> [BackupConfig]
    func saveBackupConfigs(_ configs: [BackupConfig])

    /// Per-config "last successful sync" timestamps. Plaintext storage — timestamps are not
    /// sensitive, and skipping encryption removes the `appKey` dependency so reads work in any
    /// auth state. Returns an empty map if nothing has been written or decoding fails.
    func loadLastSyncDates() -> [UUID: Date]
    func saveLastSyncDates(_ dates: [UUID: Date])

    /// Legacy single-config accessor, retained for one-shot migration into the new
    /// `loadBackupConfigs` list. Decrypts and decodes the pre-multi-config blob if present.
    /// Returns `nil` once `clearLegacyWebDAVSavedConfig()` has been called or no legacy blob
    /// was ever stored.
    var legacyWebDAVSavedConfig: BackupWebDAVConfig? { get }
    func clearLegacyWebDAVSavedConfig()

    var webDAVSeedHash: String? { get }
    var webDAVCurrentVaultID: VaultID? { get }

    var webDAVWriteDecryptedCopy: Bool { get }
    func webDAVSetWriteDecryptedCopy(_ writeDecryptedCopy: Bool)

    /// Set of backup-config IDs that should overwrite their remote on the next sync. Populated
    /// by `MainModuleInteractor.passwordWasChanged()` for every file-based backend (`.webDAV`,
    /// `.s3`); each entry is removed by the global progress observer the first time that
    /// specific config syncs successfully. Per-id (rather than a single Bool) so a multi-config
    /// user with N WebDAV / S3 backends gets all of them re-pushed after a master-password
    /// change, not just whichever one finishes first.
    var vaultOverrideAwaitingConfigIDs: Set<UUID> { get }
    func markVaultOverrideAwaiting(configIDs: Set<UUID>)
    func clearVaultOverrideAwaiting(configID: UUID)

    /// Set of backup-config IDs awaiting their first successful sync after recovery. The
    /// recovery flow needs to write *this* device's `deviceID` into the WebDAV index so
    /// subsequent routine syncs (which use `allowingAnyDeviceId: false`) don't trip the
    /// multi-device-id gate when merging a vault that originated on another device. The
    /// post-import `performRecoverySync` is the first attempt, but it can fail (network,
    /// lock contention, server hiccup); the flag persists through those failures so the next
    /// sync attempt — routine, manual, or otherwise — automatically retries with
    /// `allowingAnyDeviceId: true`. Each entry is cleared by `BackupSyncAdapter.setLastSyncDate`
    /// the first time a sync that *consumed* this flag (`consumed.allowingAnyDeviceId == true`)
    /// completes successfully — conditional clear, so a routine sync that happened to finish
    /// while the flag was set doesn't wipe it without honoring it.
    var deviceRegistrationAwaitingConfigIDs: Set<UUID> { get }
    func markDeviceRegistrationAwaiting(configIDs: Set<UUID>)
    func clearDeviceRegistrationAwaiting(configID: UUID)

    // MARK: 2FAS Web Service
    func appNotifications() async throws -> AppNotifications
    func deleteAppNotification(id: String) async throws

    // MARK: Share Service
    func createSharedSecret(data: Data, validForSeconds: Int, singleUse: Bool) async throws -> ShareSecretResponse
    func fetchSharedSecret(id: String) async throws -> SharedSecret
    
    // MARK: - Scan
    func scan(image: UIImage, completion: @escaping (Result<[String], ScanImageError>) -> Void)
    
    // MARK: - Screen Capture
    var screenCaptureAllowedUntil: Date? { get }
    func setScreenCaptureAllowedUntil(_ date: Date)
    func clearScreenCaptureAllowedUntil()

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

    // MARK: - Backup Sync Container
    /// The app-lifetime `BackupSyncContainer`. Single instance for the process lifetime —
    /// constructed inert by `MainRepositoryImpl.init`, then wired by
    /// `BackupSyncSetupInteractor.initialize()` (called from
    /// `RootModuleInteractor.initializeApp()`) via `BackupSyncContainer.setup(...)`.
    /// Reads before setup-time no-op gracefully (zero services, `.idle` activity).
    var backupSyncContainer: BackupSyncContainer { get }
}
