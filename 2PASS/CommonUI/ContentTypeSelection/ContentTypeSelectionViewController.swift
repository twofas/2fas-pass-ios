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
