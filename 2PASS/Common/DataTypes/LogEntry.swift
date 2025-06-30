// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct LogEntry: Hashable {
    public let content: String
    public let timestamp: Date
    public let module: LogModule
    public let severity: LogSeverity
        
    public init(content: String, timestamp: Date, module: LogModule, severity: LogSeverity) {
        self.content = content
        self.timestamp = timestamp
        self.module = module
        self.severity = severity
    }
}
