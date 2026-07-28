// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

final class ContentTypeSelectionViewController: UIViewController {
    var flowController: ContentTypeSelectionFlowController!
    
    var onSelect: ((ItemContentType) -> Void)?
    var onClose: (() -> Void)?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupContentTypeSelectionView()
        configurePopoverSize()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // This selection is a popover anchored to the "+" bar button. When the app is resized (iPad
        // multitasking, Stage Manager, rotation) the anchor moves and the Main layout may even swap
        // between the sidebar split and the tab bar, leaving the popover orphaned or mis-anchored.
        // Per Apple's guidance, dismiss it on a size change instead of trying to reposition it — via the
        // same cancel path as the close button so the parent flow controller cleans up consistently.
        //
        // Only act on a genuine resize while the popover is the bare, fully-settled top screen. Skip it:
        // - while the popover runs its own present/dismiss animation (UIKit also calls this then) —
        //   closing there tears the popover down mid-transition and crashes;
        // - once a type has been picked and the item editor is presented on top of the popover — the
        //   dismiss would cascade down the chain and kill the in-progress editor.
        guard modalPresentationStyle == .popover,
              isBeingPresented == false,
              isBeingDismissed == false,
              presentedViewController == nil,
              viewIfLoaded?.window != nil else { return }
        onClose?()
    }

    private func setupContentTypeSelectionView() {
        let contentTypeSelectionView = ContentTypeSelectionView(
            onSelect: { [weak self] contentType in
                self?.onSelect?(contentType)
            },
            onClose: { [weak self] in
                self?.onClose?()
            }
        )

        let hostingController = UIHostingController(rootView: contentTypeSelectionView)
        hostingController.view.backgroundColor = .clear
        placeChild(hostingController)
    }

    private func configurePopoverSize() {
        let rowHeight: CGFloat = 40 + (Spacing.s * 2)
        let numberOfRows = ItemContentType.allKnownTypes.count
        let horizontalPadding = Spacing.l * 2

        let width: CGFloat = 250
        let height = rowHeight * CGFloat(numberOfRows) + horizontalPadding

        preferredContentSize = CGSize(width: width, height: height)
    }
}

extension ContentTypeSelectionViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController) {
        popoverPresentationController.presentedViewController.view.layoutIfNeeded()
    }
    
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return true
    }
}
