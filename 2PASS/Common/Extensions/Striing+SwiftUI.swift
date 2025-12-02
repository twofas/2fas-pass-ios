// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension String {
    
    public var localizedKey: LocalizedStringKey {
        .init(self)
    }
    
    public var localizedResource: LocalizedStringResource {
        .init(stringLiteral: self)
    }
}
