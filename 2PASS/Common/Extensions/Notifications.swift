// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public extension Notification.Name {
    static let orientationSizeWillChange = Notification.Name("orientationSizeWillChange")
    static let tokensScreenIsVisible = Notification.Name("tokensScreenIsVisible")
    static let userLoggedIn = Notification.Name("userLoggedIn")
    static let cloudStateChanged = Notification.Name("cloudStateChanged")
    static let cloudRefreshLocalData = Notification.Name("cloudRefreshLocalData")
    static let cloudDidSync = Notification.Name("cloudDidSync")
    static let passwordWasChanged = Notification.Name("passwordWasChanged")
    static let paymentStatusChanged = Notification.Name("paymentStatusChanged")
    static let presentPaymentScreen = Notification.Name("presentPaymentScreen")
    static let presentSyncPremiumNeededScreen = Notification.Name("presentSyncPremiumNeededScreen")
    static let didImportItems = Notification.Name("didImportItems")
    static let showUpdateAppPrompt = Notification.Name("showUpdateAppPrompt")
    static let screenCaptureAllowanceDidChange = Notification.Name("screenCaptureAllowanceDidChange")
    /// Posted by `MainModuleInteractor` whenever the sync error badge state changes, so the
    /// Settings screen's "Sync" row can refresh its trailing icon. Distinct from per-run
    /// lifecycle (which is observable via `BackupSyncContainer.progressEvents()`) — this fires
    /// only on the composite "is there an error to surface right now" verdict.
    static let settingsSyncStateChanged = Notification.Name("settingsSyncStateChanged")
}

public extension Notification {
    static let showUpdateAppPromptReasonKey = "showUpdateAppPromptReasonKey"
}
