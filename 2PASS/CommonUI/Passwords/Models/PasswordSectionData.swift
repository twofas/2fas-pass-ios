// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

struct PasswordSectionData: Hashable {
    let sectionID = UUID()
    let title: String?
    
    init(title: String? = nil) {
        self.title = title
    }
}
