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

    private var badgeSubscription: Task<Void, Never>?

    private var reviewSubscription: Task<Void, Never>?

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

        reviewSubscription = Task { [weak self] in
            guard let stream = self?.interactor.reviewRequests else { return }
            for await _ in stream {
                await self?.presentStoreReview()
            }
        }
    }

    deinit {
        badgeSubscription?.cancel()
        reviewSubscription?.cancel()
    }

    @MainActor
    private func applyBadge(_ showError: Bool) {
        if showError {
            view?.showBadge()
        } else {
            view?.hideBadge()
        }
    }

    @MainActor
    private func presentStoreReview() {
        flowController.requestStoreReview()
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
