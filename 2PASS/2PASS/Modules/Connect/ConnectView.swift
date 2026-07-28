// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct ConnectView: View {

    @State
    var presenter: ConnectPresenter

    /// Dismisses Connect when it is presented modally (iPad sidebar footer); wired by the host
    /// coordinator. Only surfaced (as the Cancel item) while `presenter.isModalPresentation`.
    var onCloseHandler: (() -> Void)?

    var body: some View {
        // The navigation stack is always present so the view structure stays stable when the single
        // shared instance flips between the tab and the split modal — restructuring the hierarchy
        // would reset SwiftUI state (and the camera session) mid-flight. Only the chrome toggles:
        // the modal gets a navigation bar with a Cancel item, the tab hides the bar entirely.
        NavigationStack {
            connectBody
                .toolbar {
                    if presenter.isModalPresentation {
                        ToolbarCancelItem(action: { onCloseHandler?() })
                    }
                }
                .toolbar(presenter.isModalPresentation ? .automatic : .hidden, for: .navigationBar)
        }
    }

    private var connectBody: some View {
        ZStack {
            if presenter.isCameraAllowed {
                ConnectCameraView(presenter: presenter.cameraPresenter)
            } else if let introPresenter = presenter.introPresenter {
                ConnectIntroView(presenter: introPresenter)
            }
        }
        .router(router: ConnectRouter(), destination: $presenter.destination)
    }

    func onClose(_ handler: (() -> Void)?) -> Self {
        var instance = self
        instance.onCloseHandler = handler
        return instance
    }
}
