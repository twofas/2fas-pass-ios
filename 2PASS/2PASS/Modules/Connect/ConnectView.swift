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
    
    var body: some View {
        ZStack {
            if presenter.isCameraAllowed {
                ConnectCameraView(presenter: presenter.cameraPresenter)
            } else if let introPresenter = presenter.introPresenter {
                ConnectIntroView(presenter: introPresenter)
            }
        }
        .router(router: ConnectRouter(), destination: $presenter.destination)
    }
}
