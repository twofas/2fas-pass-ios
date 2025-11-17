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
        configurePresentation()
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
        placeChild(hostingController)
    }

    private func configurePresentation() {
        modalPresentationStyle = .pageSheet

        if let sheet = sheetPresentationController {
            sheet.prefersGrabberVisible = true

            // Calculate height dynamically based on content
            let headerHeight: CGFloat = 20 + Spacing.m + Spacing.m
            let rowHeight: CGFloat = 40 + (Spacing.s * 2)
            let numberOfRows: CGFloat = 2 // Login and Secure Note
            let contentListHeight = rowHeight * numberOfRows
            let horizontalPadding = Spacing.l * 2
            let dragIndicatorSpace: CGFloat = 20
            let calculatedHeight = headerHeight + contentListHeight + horizontalPadding + dragIndicatorSpace

            sheet.detents = [.custom { _ in calculatedHeight }]
        }
    }
}
