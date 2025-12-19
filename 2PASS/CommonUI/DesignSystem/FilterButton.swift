// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public final class FilterButton: UIButton {

    private let activeBadge = UIView()

    public var isFilterActive: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = UIButton.Configuration.glass()
        } else {
            config = UIButton.Configuration.plain()
        }

        config.image = UIImage(systemName: "ellipsis")
        configuration = config

        activeBadge.backgroundColor = .danger500
        activeBadge.layer.cornerRadius = 6
        activeBadge.translatesAutoresizingMaskIntoConstraints = false
        activeBadge.alpha = 0

        addSubview(activeBadge)

        NSLayoutConstraint.activate([
            activeBadge.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            activeBadge.centerYAnchor.constraint(equalTo: topAnchor, constant: 6),
            activeBadge.widthAnchor.constraint(equalToConstant: 12),
            activeBadge.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    private func updateAppearance() {
        activeBadge.alpha = isFilterActive ? 1 : 0
    }
}
