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

    /// Drives the tab-bar badge from `interactor.badgeUpdates` (a dedupped passthrough to
    /// `BackupSyncTriggerInteractor.syncErrorChanges`). Cancelled in `deinit` so the stream's
    /// upstream subscriptions tear down when the presenter goes away. `var ...?` per the
    /// Swift two-phase init exception (CLAUDE.md): the Task captures `[weak self]` and so
    /// cannot be assigned during phase-one init.
    private var badgeSubscription: Task<Void, Never>?

    init(flowController: MainFlowControlling, interactor: MainModuleInteracting) {
        self.flowController = flowController
        self.interactor = interactor

        interactor.paymentScreen = { [weak flowController] in
            flowController?.toPayment()
        }

        badgeSubscription = Task { [weak self] in
            guard let stream = self?.interactor.badgeUpdates else { return }
            for await showError in stream {
                await self?.applyBadge(showError)
            }
        }
    }

    deinit {
        badgeSubscription?.cancel()
    }

    @MainActor
    private func applyBadge(_ showError: Bool) {
        if showError {
            view?.showBadge()
        } else {
            view?.hideBadge()
        }
    }

    func viewDidAppear() {
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
