// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum VaultDataKind: Sendable, CaseIterable {
    case items
    case tags
}

/// Posted whenever the in-memory (decrypted) vault store is saved, carrying which kinds of data
/// changed so each screen can refresh only when affected.
public struct VaultDataDidChange: Notifications.MainActorMessage {
    public typealias Subject = NSObject
    public let changedKinds: Set<VaultDataKind>

    public init(changedKinds: Set<VaultDataKind>) {
        self.changedKinds = changedKinds
    }

    /// Whether this change touched any of the given kinds.
    public func affects(_ kinds: Set<VaultDataKind>) -> Bool {
        changedKinds.isDisjoint(with: kinds) == false
    }
}
