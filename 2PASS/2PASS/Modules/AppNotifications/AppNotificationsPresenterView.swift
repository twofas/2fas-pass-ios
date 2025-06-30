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
        Color.clear
            .onAppear {
                showNotificationView = true
            }
            .sheet(isPresented: $showNotificationView) {
                ConnectPullReqestCommunicationRouter.buildView(appNotification: notification)
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
