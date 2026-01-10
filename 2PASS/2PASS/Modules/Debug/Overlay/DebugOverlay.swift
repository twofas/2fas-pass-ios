// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

final class DebugOverlay {
    public static let enablingKey = "debugOverlayEnabled"
    
    private var overlayButtonWindow: UIWindow?
    private var overlayDebugWindow: UIWindow?
    private weak var mainWindow: UIWindow?
    
    private var selectedSegmentIndex = 0
    private let notificationCenter = NotificationCenter.default
    
    func initialize(window: UIWindow?) {
        mainWindow = window
        
        let y: CGFloat = {
            guard let top = window?.safeAreaInsets.top else {
                return 60.0
            }
            return top
        }()
        
        let width = UIScreen.main.bounds.width
        let size = 30.0
        let center = round((width - size)/2.0)
        
        overlayButtonWindow = UIWindow(frame: CGRect(x: center, y: y, width: size, height: size))
        overlayButtonWindow?.windowLevel = .alert + 1
        overlayButtonWindow?.isHidden = true
        
        let overlayButtonView = HostingController(rootView: OverlayButtonView(action: { [weak self] in
            self?.showDebugWindow()
        }))
        overlayButtonView.view.backgroundColor = .clear
        overlayButtonWindow?.rootViewController = overlayButtonView
        
        // Debug Window
        overlayDebugWindow = UIWindow(frame: UIScreen.main.bounds)
        overlayDebugWindow?.windowLevel = .alert + 2
        overlayDebugWindow?.isHidden = true
        
        notificationCenter.addObserver(
            self,
            selector: #selector(updateState),
            name: .debugOverlayStateChange,
            object: nil
        )
        updateState()
    }
    
    @objc
    private func updateState() {
        overlayButtonWindow?.isHidden = !UserDefaults.standard.bool(forKey: DebugOverlay.enablingKey)
    }
    
    private func showDebugWindow() {
        mainWindow?.endEditing(true)
        setupDebugView()
        overlayDebugWindow?.alpha = 0
        overlayDebugWindow?.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0, options: .beginFromCurrentState) {
            self.overlayDebugWindow?.alpha = 1
        }
    }
    
    private func hideDebugWindow() {
        UIView.animate(
            withDuration: 0.3, delay: 0, options: .beginFromCurrentState) {
                self.overlayDebugWindow?.alpha = 0
            } completion: { _ in
                self.overlayDebugWindow?.isHidden = true
                self.overlayDebugWindow?.rootViewController = nil
            }
    }
    
    private func setupDebugView() {
        let overlayDebugView = UIHostingController(
            rootView: DebugStatusView(
                selectedSegment: selectedSegmentIndex,
                close: { [weak self] in
                    self?.hideDebugWindow()
                }, selectedSegmentEvent: { [weak self] selectedSegmentIndex in
                    self?.selectedSegmentIndex = selectedSegmentIndex
                }
            )
        )
        overlayDebugView.view.backgroundColor = UIColor(resource: .mainBackground)
        overlayDebugWindow?.rootViewController = overlayDebugView
    }
}

extension Notification.Name {
    static let debugOverlayStateChange = Notification.Name("debugOverlayStateChange")
}
