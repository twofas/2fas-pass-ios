// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Storage
import Security
import LocalAuthentication
import Backup
import CryptoKit
import RevenueCat

final class MainRepositoryImpl: MainRepository {
    
    private static var _shared: MainRepositoryImpl!
    
    // MARK: State
    
    var _empheralDeviceID: UUID?
    var _ephemeralMasterKey: MasterKey?
    var _selectedVault: VaultEncryptedData?
    var _empheralSecureKey: SecureKey?
    var _empheralTrustedKey: TrustedKey?
    var _empheralExteralKey: ExternalKey?
    var _empheralSeed: Seed?
    var _empheralEntropy: Entropy?
    var _empheralWords: [String]?
    var _empheralSalt: Data?
    var _empheralMasterPassword: MasterPassword?
    var _didLoginUsingDecryptionKit = false
    var _isInBackground = false
    var _isAutoFillEnabled: Bool = false
    var _pushNotificationToken: String?
    var _startPurchaseBlock: StartPurchaseBlock?
    var _subscriptionPlan: SubscriptionPlan = .free
    var _cloudCacheInitilizingNewStore = false
    var _minimalAppVersionSupported: String?

    var _cachedS3RecoveryConfig: Data?
    var _cachedWebDAVRecoveryConfig: Data?

    // Cached values for higher pefrormance
    var cachedSortType: SortType?
    var cachedSortTypeInitialized = false
    var cachedTimeOffset: TimeInterval?
    var cachedUri = Cache<String, String>(useSynchronization: .yes(queueName: "URICacheQueue"))
    
    var authContext = LAContext()
    
    var _trustedKeySymm: SymmetricKey?
    var _secureKeySymm: SymmetricKey?
    var _externalKeySymm: SymmetricKey?
    
    let cameraPermissions: CameraPermissions
    let userDefaultsDataSource: UserDefaultsDataSource
    let initialPermissionStateDataController: PermissionsStateDataController
    let notificationCenter: NotificationCenter
    let keychainDataSource: KeychainDataSource
    let encryptedStorage: EncryptedStorageDataSource
    let feedbackGenerator: UINotificationFeedbackGenerator
    let network: NetworkDataSource
    let logDataSource: LogStorageDataSource
    let cloudCache: CloudCacheStorageDataSource
    let autoFillStatusDataSource: AutoFillStatusDataSourcing
    let pushNotificationsPermissionsDataSource: PushNotificationsPermissionsDataSourcing
    let twoFASWebServiceSession: TwoFASWebServiceSession
    let twoFASShareServiceSession: TwoFASShareServiceSession
    let revenueCatDelegate: RevenueCatDelegate
    let backupSyncContainer: BackupSyncContainer

    var inMemoryStorage: InMemoryStorageDataSource?
    var storageError: ((String) -> Void)?
    
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    
    static var shared: MainRepository {
        if _shared == nil {
            _shared = MainRepositoryImpl()
        }
        return _shared
    }
    
    init(
        cameraPermissions: CameraPermissions = .init(),
        userDefaultsDataSource: UserDefaultsDataSource = UserDefaultsDataSourceImpl(),
        initialPermissionStateDataController: PermissionsStateDataController = .init(),
        notificationCenter: NotificationCenter = .default,
        keychainDataSource: KeychainDataSource = KeychainDataSourceImpl(),
        encryptedStorage: EncryptedStorageDataSource = EncryptedStorageDataSourceImpl(),
        network: NetworkDataSource = NetworkDataSourceImpl(),
        logDataSource: LogStorageDataSource = LogStorageDataSourceImpl(),
        backupSyncContainer: BackupSyncContainer = .init(),
        cloudCache: CloudCacheStorageDataSource = CloudCacheStorageDataSourceImpl(),
        autoFillStatusDataSource: AutoFillStatusDataSourcing = AutoFillStatusDataSource(),
        pushNotificationsPermissionsDataSource: PushNotificationsPermissionsDataSourcing = PushNotificationsPermissionsDataSource(),
        twoFASWebServiceSession: TwoFASWebServiceSession = .init(baseURL: Config.twoFASBaseURL),
        twoFASShareServiceSession: TwoFASShareServiceSession = .init(baseURL: Config.twoFASShareBaseURL),
        revenueCatDelegate: RevenueCatDelegate = .init()
    ) {
        self.cameraPermissions = cameraPermissions
        self.userDefaultsDataSource = userDefaultsDataSource
        self.initialPermissionStateDataController = initialPermissionStateDataController
        self.notificationCenter = notificationCenter
        self.keychainDataSource = keychainDataSource
        self.encryptedStorage = encryptedStorage
        self.network = network
        self.logDataSource = logDataSource
        self.backupSyncContainer = backupSyncContainer
        self.cloudCache = cloudCache
        self.autoFillStatusDataSource = autoFillStatusDataSource
        self.pushNotificationsPermissionsDataSource = pushNotificationsPermissionsDataSource
        self.twoFASWebServiceSession = twoFASWebServiceSession
        self.twoFASShareServiceSession = twoFASShareServiceSession
        self.revenueCatDelegate = revenueCatDelegate
        
        feedbackGenerator = UINotificationFeedbackGenerator()

        encryptedStorage.storageError = { [weak self] in self?.storageError?($0) }
        logDataSource.storageError = { [weak self] in self?.storageError?($0) }
        cloudCache.storageError = { [weak self] in self?.storageError?($0) }
        cloudCache.initilizingNewStore = { [weak self] in self?._cloudCacheInitilizingNewStore = true }

        logDataSource.loadStore {
            LogStorage.setStorage(logDataSource)
        }
        
        cloudCache.loadStore { }
    }
}
