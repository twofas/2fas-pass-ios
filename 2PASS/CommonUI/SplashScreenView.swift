// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct SplashScreenView: View {
    
    public init() {}
    
    public var body: some View {
        Color.clear
            .overlay {
                Image(.smallShield)
            }
            .ignoresSafeArea()
    }
}
