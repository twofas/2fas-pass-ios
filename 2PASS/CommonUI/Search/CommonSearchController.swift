// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

protocol CommonSearchDataSourceSearchable: AnyObject {
    func setSearchPhrase(_ phrase: String)
    func clearSearchPhrase()
}

final class CommonSearchController: UISearchController {
    private var tempText: String?
    weak var searchBarDelegate: CommonSearchDataSourceSearchable?
    private let commonSearchBar = CommonSearchBar()
    
    convenience init() {
        self.init(searchResultsController: nil)
        commonSearchBar.dataSource = self
        obscuresBackgroundDuringPresentation = false
    }
    
    override var searchBar: UISearchBar { commonSearchBar }
}

extension CommonSearchController: CommonSearchDataSourceSearchable {
    func setSearchPhrase(_ phrase: String) {
        searchBarDelegate?.setSearchPhrase(phrase)
    }
    func clearSearchPhrase() {
        searchBarDelegate?.clearSearchPhrase()
    }
}
