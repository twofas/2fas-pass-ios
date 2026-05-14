// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupConfigToolbarTitle: ToolbarContent {
    let kind: BackupSyncService
    let title: Text

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: Spacing.s) {
                BackupServiceIcon(kind: kind)
                    .controlSize(.small)
                title
                    .font(.headline)
            }
        }
    }
}

extension BackupConfigToolbarTitle {

    init(kind: BackupSyncService, title: LocalizedStringResource) {
        self.init(kind: kind, title: Text(title))
    }
}
