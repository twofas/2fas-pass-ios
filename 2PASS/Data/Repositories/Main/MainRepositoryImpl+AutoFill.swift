// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension MainRepositoryImpl {

    var didAutoFillStatusChanged: NotificationCenter.Notifications {
        autoFillStatusDataSource.didStatusChanged
    }
    
    var isAutoFillEnabled: Bool {
        autoFillStatusDataSource.isEnabled
    }

    @discardableResult
    func refreshAutoFillStatus() async -> Bool {
        await autoFillStatusDataSource.refreshStatus()
    }
    
    @available(iOS 18, *)
    func requestAutoFillPermissions() async {
        await autoFillStatusDataSource.requestAutoFillPermissions()
    }
}
