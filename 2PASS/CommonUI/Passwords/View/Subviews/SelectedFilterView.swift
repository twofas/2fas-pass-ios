// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

final class SelectedFilterView: UIView {

    var onTagClose: ((ItemTagData) -> Void)?
    var onProtectionLevelClose: ((ItemProtectionLevel) -> Void)?

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .leading
        stack.distribution = .equalSpacing
        stack.spacing = Spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var tagChipView: FilterChipView?
    private var protectionLevelChipView: FilterChipView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }

    func setTag(_ tag: ItemTagData?) {
        tagChipView?.removeFromSuperview()
        tagChipView = nil
        
        guard let tag else { return }
        addTagChip(tag)
    }

    func setProtectionLevel(_ protectionLevel: ItemProtectionLevel?) {
        protectionLevelChipView?.removeFromSuperview()
        protectionLevelChipView = nil
        
        guard let protectionLevel else { return }
        addProtectionLevelChip(protectionLevel)
    }

    private func addTagChip(_ tag: ItemTagData) {
        let chipView = FilterChipView(tag: tag)
        chipView.onClose = { [weak self] in
            self?.onTagClose?(tag)
        }
        chipView.translatesAutoresizingMaskIntoConstraints = false

        stackView.addArrangedSubview(chipView)
        tagChipView = chipView
    }

    private func addProtectionLevelChip(_ protectionLevel: ItemProtectionLevel) {
        let chipView = FilterChipView(protectionLevel: protectionLevel)
        chipView.onClose = { [weak self] in
            self?.onProtectionLevelClose?(protectionLevel)
        }
        chipView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.insertArrangedSubview(chipView, at: 0)
        protectionLevelChipView = chipView
    }
}
