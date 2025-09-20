// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

final class MainPresenter {
    private let flowController: MainFlowControlling
    private let interactor: MainModuleInteracting
    private let waitingTime: Duration = .milliseconds(750)
    
    weak var view: (any MainViewControlling)?
    
    private var didAppear = false
    
    init(flowController: MainFlowControlling, interactor: MainModuleInteracting) {
        self.flowController = flowController
        self.interactor = interactor
        
        interactor.updateBadge = { [weak self] showError in
            DispatchQueue.main.async {
                if showError {
                    self?.view?.showBadge()
                } else {
                    self?.view?.hideBadge()
                }
            }
        }
        interactor.paymentScreen = { [weak flowController] in
            flowController?.toPayment()
        }
    }
    
    func viewDidAppear() {
        guard !didAppear else { return }
        didAppear = true
        interactor.viewIsVisible()
        
        if interactor.shouldShowQuickSetup {
            Task { @MainActor in
                try await Task.sleep(for: waitingTime)
                flowController.toQuickSetup()
            }
        } else if interactor.shouldRequestForBiometryToLogin {
            Task { @MainActor in
                try await Task.sleep(for: waitingTime)
                flowController.toRequestEnableBiometry()
            }
        }
    }
    
    func viewWillDisappear() {
        flowController.dismissRequestEnableBiometry()
    }
}
