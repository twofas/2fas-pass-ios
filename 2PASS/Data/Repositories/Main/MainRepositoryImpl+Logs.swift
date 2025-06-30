// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension MainRepositoryImpl {
    func listAllLogs() -> [LogEntry] {
        logDataSource.listAll()
    }
    
    func removeAllLogs() {
        logDataSource.removeAll()
    }
}
