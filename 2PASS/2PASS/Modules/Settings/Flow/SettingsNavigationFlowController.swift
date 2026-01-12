// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common
import CommonUI
import SwiftUI

protocol SettingsNavigationFlowControllerParent: AnyObject {}

final class SettingsNavigationFlowController: NavigationFlowController {
    private weak var parent: SettingsNavigationFlowControllerParent?

    static func showAsTab(
        in viewController: UITabBarController,
        parent: SettingsNavigationFlowControllerParent
    ) {
        let flowController = SettingsNavigationFlowController()
        flowController.parent = parent

        let settingsViewController = UIHostingController(rootView: SettingsRouter.buildView())
        settingsViewController.tabBarItem = UITabBarItem(
            title: String(localized: .commonSettings),
            image: UIImage(systemName: "gear"),
            selectedImage: UIImage(systemName: "gear")
        )
        
        viewController.addTab(settingsViewController)
    }
}

extension SettingsNavigationFlowController {
    func recoveryKitClose() {
        goBackToAppSecurity()
    }
}

extension SettingsNavigationFlowController {
    func backupExportToSaveFile(encrypt: Bool) {
    }
}

extension SettingsNavigationFlowController {
    func backupExportSaveFileClose() {
        goBackToBackup()
    }
}

private extension SettingsNavigationFlowController {
    func goBackToBackup() {
        guard let backupVC = navigationController.viewControllers[safe: 1] else {
            navigationController.popToRootViewController(animated: true)
            return
        }
        navigationController.popToViewController(backupVC, animated: true)
    }
    
    func goBackToAppSecurity() {
        guard let backupVC = navigationController.viewControllers[safe: 1] else {
            navigationController.popToRootViewController(animated: true)
            return
        }
        navigationController.popToViewController(backupVC, animated: true)
    }
}
