// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Data
import Common
import CommonUI

/// Owns the single shared Connect instance (one hosting controller, one presenter chain, one camera
/// session) and reparents it between its two homes as the layout swaps by width: the tab bar's Connect
/// slot (narrow) and a disposable modal container presented over the split (wide). Because the same
/// instance moves — never rebuilt — an in-progress scan survives the swap. Mirrors
/// `PasswordsHostCoordinator` for the items subtree.
///
/// Unlike Passwords, Connect has a third, implicit state: *parked* — retained here with no parent and
/// no presentation. That is its resting state in the split layout while the sidebar-footer modal is
/// closed (the camera stops on its own via view disappearance).
///
/// Also owns the scanned-connection acceptance flow for both layouts: the camera always hands the
/// scanned session up, and the acceptance sheet is presented from the container — the only view
/// controller that survives layout swaps — so an active acceptance is never orphaned by a swap.
final class ConnectHostCoordinator {

    /// The shared Connect view controller. Implicitly-unwrapped for two-phase init: the factory's
    /// closures capture `self`, which is only available once every stored property is initialized.
    private(set) var viewController: UIViewController!
    private var presenter: ConnectPresenter!

    private weak var tabBar: MainViewController?
    private weak var container: MainContainerViewController?
    private weak var splitCoordinator: MainSplitFlowController?

    /// The throwaway container currently presenting the shared view controller over the split. The
    /// shared instance is hosted as its *child* (not presented directly), so the modal lifecycle never
    /// touches the shared hosting controller itself. Weak: dismissal releases it.
    private weak var modalContainer: ConnectModalContainerViewController?

    /// The transparent host presenting the scanned-connection acceptance sheet; torn down once the
    /// sheet is gone. Presented from the container so it survives layout swaps.
    private weak var scannedCommunicationHost: UIViewController?
    /// Set when the acceptance sheet asks to rescan, so the Connect scanner is re-opened (in whichever
    /// layout is active *at that moment*) once the host has been torn down.
    private var reopenConnectAfterCommunication = false

    /// Occupies the Connect tab slot (index 1) while the shared instance is elsewhere (split modal or
    /// parked), so the Passwords (0) / Settings (2) tab indices never shift. Carries the Connect tab
    /// bar item so the slot still renders correctly if briefly visible.
    private let tabPlaceholder: UIViewController = {
        let placeholder = UIViewController()
        placeholder.tabBarItem = ConnectNavigationFlowController.makeConnectTabBarItem()
        return placeholder
    }()

    init(parent: ConnectNavigationFlowControllerParent) {
        let build = ConnectNavigationFlowController.makeShared(
            parent: parent,
            onClose: { [weak self] in self?.dismissSplitModal() },
            onScannedSession: { [weak self] session in self?.handleScannedSession(session) }
        )
        viewController = build.viewController
        presenter = build.presenter
    }

    /// The view controller seeding the Connect tab slot at build time (swapped for the shared instance
    /// on the first attach to the tab bar).
    var tabSlotPlaceholder: UIViewController { tabPlaceholder }

    func configure(
        tabBar: MainViewController,
        container: MainContainerViewController,
        splitCoordinator: MainSplitFlowController
    ) {
        self.tabBar = tabBar
        self.container = container
        self.splitCoordinator = splitCoordinator
    }

    // MARK: - Reparenting

    enum Home {
        case tab
        case splitModal
    }

    /// Where the shared instance currently lives. Derived, not stored, so a swipe-dismissed split
    /// modal self-heals to "parked" (`nil`) without any presentation-controller bookkeeping.
    var currentHome: Home? {
        guard let parent = viewController.parent else { return nil }
        return parent is UITabBarController ? .tab : .splitModal
    }

    /// Removes the shared instance from its current host without tearing it down (this coordinator
    /// retains it), dropping any in-flight permissions push/sheet so it re-enters the next home at its
    /// root. Safe to call regardless of state.
    func detachFromCurrentHost() {
        presenter.dismissTransientDestinations()
        switch currentHome {
        case .tab:
            if let tabBar, var tabs = tabBar.viewControllers,
               tabs[safe: MainViewController.connectTabIndex] === viewController {
                tabs[MainViewController.connectTabIndex] = tabPlaceholder
                tabBar.viewControllers = tabs
            }
        case .splitModal:
            // Force the reclaim here rather than waiting for the modal container's dismissal callback
            // (an unanimated dismiss may deliver it later in the runloop), so the swap sequence can
            // re-attach the instance in the same pass.
            reclaimFromModalContainer()
        case .none:
            break
        }
    }

    /// Installs the shared instance into `host`'s home. For the split that is a deliberate no-op —
    /// the instance parks until the sidebar footer (or the container's section carry-over) presents it.
    func attach(to host: PasswordsHostCoordinator.Host) {
        switch host {
        case .tab:
            guard viewController.parent == nil, viewController.presentingViewController == nil else {
                return // mid-dismissal; the placeholder stays in the slot
            }
            if let tabBar, var tabs = tabBar.viewControllers,
               tabs[safe: MainViewController.connectTabIndex] === tabPlaceholder {
                tabs[MainViewController.connectTabIndex] = viewController
                tabBar.viewControllers = tabs
            }
            presenter.apply(isModalPresentation: false)
        case .split:
            break
        }
    }

    /// Detaches the shared instance from wherever it lives, switches it to its modal chrome, and
    /// returns a fresh disposable container hosting it, ready to be presented over the split.
    func beginSplitModalPresentation() -> UIViewController {
        detachFromCurrentHost()
        presenter.apply(isModalPresentation: true)

        let modalContainer = ConnectModalContainerViewController()
        modalContainer.onDidDismiss = { [weak self] in self?.reclaimFromModalContainer() }
        modalContainer.placeChild(viewController)
        self.modalContainer = modalContainer
        return modalContainer
    }

    private func dismissSplitModal() {
        guard let modalContainer, modalContainer.presentingViewController != nil else { return }
        modalContainer.dismiss(animated: true)
    }

    /// Pulls the shared instance out of the (dismissed or being-dismissed) modal container so it parks
    /// under this coordinator's retention rather than dying with the throwaway container.
    private func reclaimFromModalContainer() {
        guard let parent = viewController.parent, parent === modalContainer else { return }
        viewController.unplaceFromParent()
        // `placeChild` pinned the view with Auto Layout (translates = false); those constraints died
        // with the container's view. The tab bar positions its children by frame + autoresizing mask,
        // so restore frame-based layout or the hosting view collapses to zero width in the tab slot.
        viewController.view.translatesAutoresizingMaskIntoConstraints = true
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    // MARK: - Scanned-connection acceptance flow

    /// After a successful scan, hide the camera first — dismiss the split's Connect modal, or switch
    /// the tab bar off the Connect tab — and then present the acceptance sheet from the container,
    /// which survives layout swaps (so the sheet is never orphaned by one). The sheet sizes itself off
    /// the window width and self-dismisses on success.
    private func handleScannedSession(_ session: ConnectSession) {
        guard let container else { return }

        // Present through a transparent SwiftUI host (not a hosting controller directly) so the
        // acceptance sheet keeps SwiftUI's layout-reactive sizing: a fitted card while the window is
        // wide, a content bottom sheet once it is narrow. A UIKit form sheet stays oversized in compact.
        let host = MainActor.assumeIsolated {
            let hostingController = UIHostingController(
                rootView: ScannedConnectionSheetHost(
                    session: session,
                    onScanAgain: { [weak self] in self?.reopenConnectAfterCommunication = true },
                    onDismiss: { [weak self] in self?.finishScannedCommunication() }
                )
            )
            hostingController.view.backgroundColor = .clear
            hostingController.modalPresentationStyle = .overFullScreen
            return hostingController
        }
        scannedCommunicationHost = host

        switch currentHome {
        case .splitModal:
            modalContainer?.dismiss(animated: true) { [weak container] in
                container?.present(host, animated: false)
            }
        case .tab:
            // Mirror the pre-shared behavior: scanning switches to the items tab before the sheet
            // appears, so the camera isn't left running underneath.
            tabBar?.select(nil)
            container.present(host, animated: false)
        case .none:
            container.present(host, animated: false)
        }
    }

    /// Tears down the acceptance host once its sheet is gone, and re-opens the Connect scanner — in
    /// whichever layout is active at that moment — if the user asked to rescan.
    private func finishScannedCommunication() {
        let shouldReopen = reopenConnectAfterCommunication
        reopenConnectAfterCommunication = false
        scannedCommunicationHost = nil

        guard let container, container.presentedViewController != nil else {
            if shouldReopen { reopenConnect() }
            return
        }
        container.dismiss(animated: false) { [weak self] in
            if shouldReopen { self?.reopenConnect() }
        }
    }

    private func reopenConnect() {
        if container?.isSplitLayoutActive == true {
            // Route through the split coordinator so its `presentedSection` tracking stays correct.
            splitCoordinator?.present(.connect)
        } else {
            tabBar?.select(.connect)
        }
    }
}

/// Disposable container presented over the split; hosts the shared Connect view controller as a child
/// so the modal lifecycle never touches the shared hosting controller directly. Notifies on dismissal
/// (programmatic or swipe) so the coordinator can reclaim its child before this container dies.
private final class ConnectModalContainerViewController: UIViewController {
    var onDidDismiss: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            onDidDismiss?()
        }
    }
}
