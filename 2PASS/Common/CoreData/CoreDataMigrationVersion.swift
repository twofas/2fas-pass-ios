// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

final class CoreDataMigrationVersionList {
    private let versions: [CoreDataMigrationVersion]
    
    init(versions: [CoreDataMigrationVersion]) {
        self.versions = versions
    }
    
    var current: CoreDataMigrationVersion {
        guard let latest = versions.last else {
            fatalError("No model versions found")
        }

        return latest
    }
    
    func first(where predicate: (CoreDataMigrationVersion) -> Bool) -> CoreDataMigrationVersion? {
        for v in versions {
            if predicate(v) { return v }
        }
        return nil
    }
    
    func nextVersion(for version: CoreDataMigrationVersion) -> CoreDataMigrationVersion? {
        guard let index = versions.firstIndex(where: { $0 == version }) else { return nil }
        return versions[safe: index + 1]
    }
    
    func isCurrentVersion(for compareVersion: CoreDataMigrationVersion) -> Bool {
        current == compareVersion
    }
}

public final class CoreDataMigrationVersion: Equatable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static func == (lhs: CoreDataMigrationVersion, rhs: CoreDataMigrationVersion) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}
