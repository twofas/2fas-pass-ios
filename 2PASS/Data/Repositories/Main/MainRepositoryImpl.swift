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
    
    var _isLockScreenActive = false
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
    var _isInBackground = false
    var _canLockApp = true
    var _webDAVState: WebDAVState = .idle
    var _isAutoFillEnabled: Bool = false
    var _pushNotificationToken: String?
    var _syncHasError = false
    var _startPurchaseBlock: StartPurchaseBlock?
    var _subscriptionPlan: SubscriptionPlan = .free
    
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
    let backupWebDAV: BackupWebDAVController
    let cloudSync: CloudSync
    let cloudCache: CloudCacheStorageDataSource
    let cloudRecovery: CloudRecovering
    let autoFillStatusDataSource: AutoFillStatusDataSourcing
    let pushNotificationsPermissionsDataSource: PushNotificationsPermissionsDataSourcing
    let twoFASWebServiceSession: TwoFASWebServiceSession
    let revenueCatDelegate: RevenueCatDelegate
    
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
        backupWebDAV: BackupWebDAVController = BackupWebDAVController(),
        cloudSync: CloudSync = CloudSync(),
        cloudCache: CloudCacheStorageDataSource = CloudCacheStorageDataSourceImpl(),
        cloudRecovery: CloudRecovering = CloudRecovery(),
        autoFillStatusDataSource: AutoFillStatusDataSourcing = AutoFillStatusDataSource(),
        pushNotificationsPermissionsDataSource: PushNotificationsPermissionsDataSourcing = PushNotificationsPermissionsDataSource(),
        twoFASWebServiceSession: TwoFASWebServiceSession = .init(baseURL: Config.twoFASBaseURL),
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
        self.backupWebDAV = backupWebDAV
        self.cloudSync = cloudSync
        self.cloudCache = cloudCache
        self.cloudRecovery = cloudRecovery
        self.autoFillStatusDataSource = autoFillStatusDataSource
        self.pushNotificationsPermissionsDataSource = pushNotificationsPermissionsDataSource
        self.twoFASWebServiceSession = twoFASWebServiceSession
        self.revenueCatDelegate = revenueCatDelegate
        
        feedbackGenerator = UINotificationFeedbackGenerator()

        encryptedStorage.storageError = { [weak self] in self?.storageError?($0) }
        logDataSource.storageError = { [weak self] in self?.storageError?($0) }
        cloudCache.storageError = { [weak self] in self?.storageError?($0) }

        LogStorage.setStorage(logDataSource)
        
        cloudCache.warmUp()
        
        updateTimeOffsetListeners()
    }
}

extension MainRepositoryImpl {
    func updateTimeOffsetListeners() {
        cloudSync.setCurrentDate(currentDate)
    }
}
