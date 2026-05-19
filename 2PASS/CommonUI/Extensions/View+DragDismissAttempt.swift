// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension View {

    /// Fires `onAttempt` when the user tries to swipe-dismiss the enclosing sheet while
    /// `isEnabled` is `true`. While enabled, the sheet's `isModalInPresentation` is set so
    /// the pull-down gesture is intercepted instead of dismissing — typical use is to
    /// present a discard-changes confirmation when there are unsaved edits, then either
    /// confirm and dismiss programmatically, or stay.
    func dragDismissAttempt(isEnabled: Bool, onAttempt: @escaping () -> Void) -> some View {
        background(DragDismissAttemptCatcher(isEnabled: isEnabled, onAttempt: onAttempt))
    }
}

/// UIKit bridge that fires `onAttempt` when the user tries to swipe-dismiss a sheet whose
/// content has unsaved changes. Sets `isModalInPresentation = true` on the sheet's
/// presentation VC (precondition for `presentationControllerDidAttemptToDismiss` callbacks)
/// and chains its delegate slot to SwiftUI's original delegate so sheet dismiss tracking,
/// detent updates, etc. continue to work.
private struct DragDismissAttemptCatcher: UIViewControllerRepresentable {
    let isEnabled: Bool
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.update(isEnabled: isEnabled, onAttempt: onAttempt)
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.uninstall()
    }

    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        private var onAttempt: () -> Void = {}
        private var isEnabled = false
        private weak var presentedTarget: UIViewController?
        private weak var originalDelegate: (any UIAdaptivePresentationControllerDelegate)?

        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            installIfNeeded()
            applyModalState()
        }

        func update(isEnabled: Bool, onAttempt: @escaping () -> Void) {
            self.onAttempt = onAttempt
            self.isEnabled = isEnabled
            installIfNeeded()
            applyModalState()
        }

        func uninstall() {
            if let target = presentedTarget,
               let presentationController = target.presentationController,
               presentationController.delegate === self {
                presentationController.delegate = originalDelegate
            }
            presentedTarget?.isModalInPresentation = false
            presentedTarget = nil
            originalDelegate = nil
        }

        private func installIfNeeded() {
            guard presentedTarget == nil else { return }
            guard let target = findPresentedAncestor() else { return }
            presentedTarget = target
            if let presentationController = target.presentationController {
                originalDelegate = presentationController.delegate
                presentationController.delegate = self
            }
        }

        private func applyModalState() {
            presentedTarget?.isModalInPresentation = isEnabled
        }

        /// Walks the parent chain to find the topmost ancestor that's actually presented as
        /// a sheet — its `presentationController` is the one whose dismiss-attempt callback
        /// we want to receive.
        private func findPresentedAncestor() -> UIViewController? {
            var current: UIViewController? = parent
            var lastPresented: UIViewController? = nil
            while let viewController = current {
                if viewController.presentingViewController != nil {
                    lastPresented = viewController
                }
                current = viewController.parent
            }
            return lastPresented
        }

        // MARK: - Delegate forwarding

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            originalDelegate
        }

        // MARK: - UIAdaptivePresentationControllerDelegate

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttempt()
            originalDelegate?.presentationControllerDidAttemptToDismiss?(presentationController)
        }
    }
}
