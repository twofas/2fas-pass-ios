// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common

@Observable
final class WiFiNetworkQRCodeScannerPresenter {

    var isCameraAvailable = true
    var showInvalidCodeError = false
    var shouldDismiss = false

    private var freezeCamera = false
    private let onScanned: (WiFiQRCodeData) -> Void
    private let cameraPermissionInteractor: CameraPermissionInteracting
    private let wifiQRCodeInteractor: WiFiQRCodeInteracting
    private let scanDebouncer = ScanDebouncer()

    init(
        onScanned: @escaping (WiFiQRCodeData) -> Void,
        cameraPermissionInteractor: CameraPermissionInteracting,
        wifiQRCodeInteractor: WiFiQRCodeInteracting
    ) {
        self.onScanned = onScanned
        self.cameraPermissionInteractor = cameraPermissionInteractor
        self.wifiQRCodeInteractor = wifiQRCodeInteractor
    }

    @MainActor
    func onAppear() {
        freezeCamera = false
        showInvalidCodeError = false
        shouldDismiss = false
        scanDebouncer.reset()
        checkCameraPermission()
    }

    @MainActor
    func onCodeFound(_ code: String) {
        guard freezeCamera == false else {
            return
        }
        scheduleDetected(code: code)
    }

    @MainActor
    func onCodeLost() {
        scheduleLost()
    }

    func onAppSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}

private extension WiFiNetworkQRCodeScannerPresenter {
    @MainActor
    func scheduleDetected(code: String) {
        scanDebouncer.scheduleDetected(
            code: code,
            task: { [weak self] code in
                guard let self else { return }

                guard let scannedData = self.wifiQRCodeInteractor.detectWiFiQRCodeData(from: code) else {
                    self.freezeCamera = false
                    self.showInvalidCodeError = true
                    return
                }

                self.freezeCamera = true
                self.showInvalidCodeError = false
                self.onScanned(scannedData)
                self.shouldDismiss = true
            }
        )
    }

    @MainActor
    func scheduleLost() {
        scanDebouncer.scheduleLost { [weak self] in
            self?.freezeCamera = false
            self?.showInvalidCodeError = false
        }
    }

    func checkCameraPermission() {
        guard cameraPermissionInteractor.isCameraAvailable else {
            isCameraAvailable = false
            return
        }

        cameraPermissionInteractor.checkPermission { [weak self] granted in
            Task { @MainActor [weak self] in
                self?.isCameraAvailable = granted
            }
        }
    }
}
