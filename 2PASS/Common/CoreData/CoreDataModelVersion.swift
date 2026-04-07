// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol CoreDataModelVersionProtocol {
    var versionName: String { get }
}

public struct CoreDataModelVersion: CoreDataModelVersionProtocol {
    public let versionName: String

    public init(_ versionName: String) {
        self.versionName = versionName
    }
}

struct CoreDataModelVersionList<Version: CoreDataModelVersionProtocol> {
    private let versions: [Version]

    init(versions: [Version]) {
        self.versions = versions
    }

    var current: Version {
        guard let latest = versions.last else {
            fatalError("No model versions found")
        }
        return latest
    }

    func first(where predicate: (Version) -> Bool) -> Version? {
        for version in versions {
            if predicate(version) { return version }
        }
        return nil
    }

    func nextVersion(for version: Version) -> Version? {
        guard let index = versions.firstIndex(where: { $0.versionName == version.versionName }) else { return nil }
        return versions[safe: index + 1]
    }

    func isCurrentVersion(for version: Version) -> Bool {
        current.versionName == version.versionName
    }
}
