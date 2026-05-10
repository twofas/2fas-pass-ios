// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupConfigToolbarTitle: ToolbarContent {
    let kind: SyncServiceKind
    let title: Text

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: Spacing.s) {
                BackupConfigIcon(kind: kind, size: 32)
                title
                    .font(.headline)
            }
        }
    }
}

extension BackupConfigToolbarTitle {

    init(kind: SyncServiceKind, title: LocalizedStringResource) {
        self.init(kind: kind, title: Text(title))
    }
}
