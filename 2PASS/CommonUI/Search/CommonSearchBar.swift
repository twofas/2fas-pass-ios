// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

final class CommonSearchBar: UISearchBar {
    private var shouldEndEditing = true
    
    var dataSource: CommonSearchDataSourceSearchable?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        placeholder = T.commonSearch
        delegate = self
        barStyle = .default
        searchBarStyle = .minimal
        tintColor = Asset.accentColor.color
        barTintColor = Asset.accentColor.color
        sizeToFit()
    }
    
    func dismiss() {
        guard let text, !text.isEmpty else {
            clear()
            return
        }
        shouldEndEditing = true
        resignFirstResponder()
    }
    
    func clear() {
        text = ""
        shouldEndEditing = true
        dataSource?.clearSearchPhrase()
        resignFirstResponder()
    }
}

extension CommonSearchBar: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        shouldEndEditing = false
        dataSource?.setSearchPhrase(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        shouldEndEditing = true
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        clear()
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        if shouldEndEditing {
            return true
        } else {
            shouldEndEditing = true
            return false
        }
    }
}

