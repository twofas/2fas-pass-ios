// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol PermissionsStateChildDataControllerProtocol: AnyObject {
    func checkState()
}

final class PermissionsStateDataController {
    private var children: [PermissionsStateChildDataControllerProtocol] = []
    
    init() {}
    
    func set(children: [PermissionsStateChildDataControllerProtocol]) {
        self.children = children
    }
    
    func initialize() {
        children.forEach { $0.checkState() }
    }
}
