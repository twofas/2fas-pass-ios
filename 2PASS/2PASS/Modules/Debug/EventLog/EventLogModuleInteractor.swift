// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data

protocol EventLogModuleInteracting: AnyObject {
    func listAll() -> [LogEntry]
}

final class EventLogModuleInteractor {
    private let debugInteractor: DebugInteracting
    
    init(debugInteractor: DebugInteracting) {
        self.debugInteractor = debugInteractor
    }
}

extension EventLogModuleInteractor: EventLogModuleInteracting {
    func listAll() -> [LogEntry] {
        debugInteractor.listAllLogEntries()
    }
}
