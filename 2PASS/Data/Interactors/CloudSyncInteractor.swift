// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Backup

public protocol CloudSyncInteracting: AnyObject {
    var currentState: CloudState { get }
    var lastSuccessSyncDate: Date? { get }
    func setup(takeoverVault: Bool)
    func synchronize()
    func enable()
    func disable()
    func clearBackup()
}

final class CloudSyncInteractor {
    private let cloudCacheStorage: CloudCacheStorage
    private let encryptionHandler: EncryptionHandler
    private let localStorage: LocalStorage
    private let mainRepository: MainRepository
    private let paymentStatusInteractor: PaymentStatusInteracting
        
    private var cloudDidSyncObservation: Task<Void, Never>?
    private var paymentStatusChanged: Task<Void, Never>?
    
    private var takeoverVault = false
    
    init(
        cloudCacheStorage: CloudCacheStorage,
        encryptionHandler: EncryptionHandler,
        localStorage: LocalStorage,
        mainRepository: MainRepository,
        paymentStatusInteractor: PaymentStatusInteracting
    ) {
        self.cloudCacheStorage = cloudCacheStorage
        self.encryptionHandler = encryptionHandler
        self.localStorage = localStorage
        self.mainRepository = mainRepository
        self.paymentStatusInteractor = paymentStatusInteractor
        
        cloudDidSyncObservation = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .cloudDidSync) {
                self?.cloudDidSync()
            }
        }
    }
    
    deinit {
        cloudDidSyncObservation?.cancel()
    }
}

extension CloudSyncInteractor: CloudSyncInteracting {
    var currentState: CloudState {
        mainRepository.cloudCurrentState
    }
    
    var lastSuccessSyncDate: Date? {
        mainRepository.lastSuccessCloudSyncDate
    }
    
    func setup(takeoverVault: Bool = false) {
        self.takeoverVault = takeoverVault
        guard let deviceID = mainRepository.deviceID else {
            Log("CloudSyncInteractor - Can't synchronize. No device ID", module: .interactor, severity: .error)
            return
        }
        mainRepository.cloudSync.setup(
            localStorage: localStorage,
            cloudCacheStorage: cloudCacheStorage,
            encryptionHandler: encryptionHandler,
            deviceID: deviceID,
            jsonDecoder: mainRepository.jsonDecoder,
            jsonEncoder: mainRepository.jsonEncoder
        )
        guard let currentVaultID = mainRepository.selectedVault?.vaultID else {
            Log("CloudSyncInteractor - Can't synchronize. No selected Vault", module: .interactor, severity: .error)
            return
        }
        mainRepository.cloudSync.setVaultID(currentVaultID)
        mainRepository.cloudSync.setMultiDeviceSyncEnabled(paymentStatusInteractor.entitlements.multiDeviceSync || takeoverVault)
        mainRepository.cloudSync.checkState()
        
        if !takeoverVault {
            setupPaymentStatusListener()
        }
    }
    
    func synchronize() {
        mainRepository.synchronizeBackup()
    }
    
    func enable() {
        mainRepository.enableCloudBackup()
    }
    
    func disable() {
        mainRepository.disableCloudBackup()
    }
    
    func clearBackup() {
        mainRepository.clearBackup()
    }
    
    private func cloudDidSync() {
        mainRepository.setLastSuccessCloudSyncDate(mainRepository.currentDate)
    }
    
    private func setupPaymentStatusListener() {
        paymentStatusChanged = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .paymentStatusChanged) {
                guard let repository = self?.mainRepository, let interactor = self?.paymentStatusInteractor else { return }
                repository.cloudSync.setMultiDeviceSyncEnabled(interactor.entitlements.multiDeviceSync)
            }
        }
    }
}
