// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

final class CommonSearchBar: UISearchBar {    
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
        resignFirstResponder()
    }
    
    func clear() {
        text = ""
        dataSource?.clearSearchPhrase()
        resignFirstResponder()
    }
}

extension CommonSearchBar: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        dataSource?.setSearchPhrase(searchText)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        clear()
    }
}

