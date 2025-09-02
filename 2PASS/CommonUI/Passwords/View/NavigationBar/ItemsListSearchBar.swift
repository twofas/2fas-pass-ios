// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

class ItemsListSearchBar: UIView {
    
    let searchBar = CommonSearchBar()
    
    private let filterButton = UIButton(type: .custom)
    private let cancelButton = UIButton(type: .system)
    private let stackView = UIStackView()
    
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = Spacing.s
        stackView.clipsToBounds = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        filterButton.layer.cornerRadius = 10
        filterButton.setContentHuggingPriority(.required, for: .horizontal)
        filterButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let filterIcon = UIImage(resource: .listConfigurationIcon).withRenderingMode(.alwaysTemplate)
        filterButton.setImage(filterIcon, for: .normal)
        
        searchBar.automaticallyShowCancel = false
        searchBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchBar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        cancelButton.setTitle(T.commonCancel, for: .normal)
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        cancelButton.isHidden = true
        
        stackView.addArrangedSubview(searchBar)
        stackView.addArrangedSubview(filterButton)
        stackView.addArrangedSubview(cancelButton)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.l),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.l),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            filterButton.widthAnchor.constraint(equalToConstant: 36),
            filterButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        updateFilterButtonAppearance()
    }
    
    @objc private func cancelButtonTapped() {
        searchBar.text = ""
        searchBar.dismiss()
        searchBar.dataSource?.clearSearchPhrase()
    }
    
    func setShowsCancelButton(_ showsCancelButton: Bool, animated: Bool) {
        if showsCancelButton {
            self.cancelButton.alpha = 1
        }
        
        if animated {
            UIView.animate(springDuration: 0.3) {
                self.cancelButton.isHidden = !showsCancelButton
            
                if showsCancelButton == false {
                    self.cancelButton.alpha = 0
                }
                
                self.stackView.layoutIfNeeded()
            }
        } else {
            cancelButton.isHidden = !showsCancelButton
        }
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
}
