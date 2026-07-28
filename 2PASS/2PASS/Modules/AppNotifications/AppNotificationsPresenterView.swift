// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let dismissAnimationDuration: Duration = .milliseconds(350)
}

struct AppNotificationsPresenterView: View {
    
    let notification: AppNotification
    let onDismiss: Callback

    @State
    private var showNotificationView: Bool = false

    var body: some View {
        // Measure the window width at the full-screen notification-window root (the presented sheet's own
        // content can't be trusted for this). Drive the sheet's sizing off the Main screen's split/tab
        // layout rather than the size class, so it matches the actual layout in the in-between widths where
        // they diverge (e.g. 11" iPad portrait is `.regular` but shows the tab bar).
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    showNotificationView = true
                }
                .sheet(isPresented: $showNotificationView) {
                    // Sizing lives inside `ConnectCommunicationSheetView` (`.fitted` on iOS 18, height
                    // detents on 17.4). Here we only supply the split/tab signal the sheet can't read
                    // itself, which drives the 17.4 fallback's iPad default-page-sheet behaviour.
                    ConnectPullReqestCommunicationRouter.buildView(appNotification: notification)
                        .environment(\.prefersDefaultSheetSize, MainLayout.usesSplitLayout(atWidth: proxy.size.width))
                }
                .onChange(of: showNotificationView) { oldValue, newValue in
                    if newValue == false {
                        Task {
                            try await Task.sleep(for: Constants.dismissAnimationDuration)
                            onDismiss()
                        }
                    }
                }
        }
    }
}
