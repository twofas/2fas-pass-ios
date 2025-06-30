// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public extension Date {
    
    static let importPasswordPlaceholder = Date(timeIntervalSince1970: 0)
    
    var exportTimestamp: Int {
        Int(timeIntervalSince1970 * 1000)
    }
    
    init(exportTimestamp: Int) {
        self.init(timeIntervalSince1970: Double(exportTimestamp)/1000)
    }
    
    func fileDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: self)
        return dateString
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
    }
    
    func fileDateAndTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: self)
        return dateString
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
    }

    func isAfter(_ date: Date) -> Bool {
        self > date
    }
    
    func isBefore(_ date: Date) -> Bool {
        self < date
    }
    
    func isSame(as date: Date) -> Bool {
        self == date
    }
}
