// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension String? {
    var formattedName: String? {
        guard let self, !self.isEmpty else {
            return nil
        }
        return self
    }
}
