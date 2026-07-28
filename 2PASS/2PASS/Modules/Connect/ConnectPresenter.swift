// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import Data

enum ConnectDestination: RouterDestination {
    case permissions(onFinish: Callback, routingType: RoutingType)

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

    /// Whether Connect is currently shown as a modal over the iPad split (Cancel item, permissions
    /// pushed onto its navigation stack) rather than as a tab (no chrome, permissions as a sheet).
    /// Flipped at runtime by the host coordinator as the single shared instance is reparented
    /// between the two homes.
    private(set) var isModalPresentation = false

    let cameraPresenter: ConnectCameraPresenter

    private(set) var introPresenter: ConnectIntroPresenter?

    private let interactor: ConnectModuleInteracting

    init(
        interactor: ConnectModuleInteracting,
        cameraInteractor: ConnectCameraModuleInteracting,
        onScannedSession: @escaping (ConnectSession) -> Void
    ) {
        self.interactor = interactor
        #if DEBUG
        self.isCameraAllowed = interactor.isE2ECameraForced || interactor.isCameraAllowed
        #else
        self.isCameraAllowed = interactor.isCameraAllowed
        #endif

        self.cameraPresenter = .init(interactor: cameraInteractor, onScannedSession: onScannedSession)

        self.introPresenter = .init(onContinue: { [weak self] in
            self?.onIntroContinue()
        })
    }

    /// Switches the presenter between its tab and split-modal presentation modes, dropping any
    /// in-flight destination so a permissions push/sheet doesn't ride into the other layout.
    func apply(isModalPresentation: Bool) {
        self.isModalPresentation = isModalPresentation
        destination = nil
    }

    /// Drops any in-flight destination (the permissions push/sheet) when the shared instance is
    /// detached from its host, so it re-enters the next home at its root.
    func dismissTransientDestinations() {
        destination = nil
    }

    private func onIntroContinue() {
        destination = .permissions(
            onFinish: { [weak self] in
                self?.refreshPermissions()
                self?.destination = nil
            },
            // Modal Connect hosts a navigation stack, so push the permissions step instead of
            // stacking another sheet on top of the modal. Resolved at tap time — the shared
            // instance switches modes as it moves between the split modal and the tab.
            routingType: isModalPresentation ? .push : .sheet
        )
    }

    private func refreshPermissions() {
        isCameraAllowed = interactor.isCameraAllowed
    }
}
