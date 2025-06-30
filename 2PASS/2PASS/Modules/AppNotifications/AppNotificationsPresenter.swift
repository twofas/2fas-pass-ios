// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import SwiftUI

final class AppNotificationsPresenter {
    
    private let window: UIWindow
    
    private var presentedViewController: UIViewController?
    
    init(windowLevel: UIWindow.Level) {
        self.window = UIWindow()
        self.window.windowLevel = windowLevel
        self.window.backgroundColor = .clear
    }
    
    func present(_ notification: AppNotification) {
        guard presentedViewController == nil else {
            return
        }
        
        window.isHidden = false
        
        let rootViewController = UIHostingController(rootView: AppNotificationsPresenterView(
            notification: notification,
            onDismiss: { [weak self] in
                self?.presentedViewController = nil
                self?.window.isHidden = true
            }
        ))
        
        rootViewController.view.backgroundColor = UIColor.clear
        window.rootViewController = rootViewController
        presentedViewController = rootViewController
    }
}
