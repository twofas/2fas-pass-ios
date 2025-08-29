// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

class ItemsListSearchBar: UIView {
    
    let searchBar = CommonSearchBar()
    private let filterButton = UIButton(type: .custom)
    
     var filterMenu: UIMenu? {
        didSet {
            filterButton.menu = filterMenu
            filterButton.showsMenuAsPrimaryAction = true
        }
    }
    
    var isFilterActive: Bool = false {
        didSet {
            updateFilterButtonAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    private func setupViews() {
        // Setup filter button with Figma design
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.layer.cornerRadius = 10
        
        // Configure button image
        let filterIcon = UIImage(resource: .listConfigurationIcon).withRenderingMode(.alwaysTemplate)
        filterButton.setImage(filterIcon, for: .normal)
        
        // Setup search bar
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        addSubview(searchBar)
        addSubview(filterButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Filter button on the right with Figma sizing
            filterButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.l),
            filterButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            filterButton.widthAnchor.constraint(equalToConstant: 36),
            filterButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Search bar takes remaining space
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.l),
            searchBar.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -Spacing.s),
            searchBar.topAnchor.constraint(equalTo: topAnchor),
            searchBar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        updateFilterButtonAppearance()
    }
    
    private func updateFilterButtonAppearance() {
        if isFilterActive {
            filterButton.backgroundColor = .brand500
            filterButton.tintColor = .white
        } else {
            filterButton.backgroundColor = UIColor.tertiarySystemFill
            filterButton.tintColor = UIColor.neutral900
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
