// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI

enum ConnectDestination: RouterDestination {
    case permissions(onFinish: Callback)
    
    var id: String {
        switch self {
        case .permissions: "permissions"
        }
    }
}

@Observable
final class ConnectPresenter {
    
    var destination: ConnectDestination?
    
    private(set) var isCameraAllowed: Bool

    let onScannedQRCode: Callback
    let onScanAgain: Callback

    private(set) var introPresenter: ConnectIntroPresenter?

    private let interactor: ConnectModuleInteracting

    init(interactor: ConnectModuleInteracting, onScannedQRCode: @escaping Callback, onScanAgain: @escaping Callback) {
        self.interactor = interactor
        self.onScannedQRCode = onScannedQRCode
        self.onScanAgain = onScanAgain
        #if DEBUG
        self.isCameraAllowed = interactor.isE2ECameraForced || interactor.isCameraAllowed
        #else
        self.isCameraAllowed = interactor.isCameraAllowed
        #endif

        self.introPresenter = .init(onContinue: { [weak self] in
            self?.onIntroContinue()
        })
    }
    
    private func onIntroContinue() {
        destination = .permissions(onFinish: { [weak self] in
            self?.refreshPermissions()
            self?.destination = nil
        })
    }
    
    private func refreshPermissions() {
        isCameraAllowed = interactor.isCameraAllowed
    }
}
