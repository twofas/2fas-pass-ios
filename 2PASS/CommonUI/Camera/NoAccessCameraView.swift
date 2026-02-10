// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct NoAccessCameraView: View {
    let onSettings: () -> Void

    public init(onSettings: @escaping () -> Void) {
        self.onSettings = onSettings
    }
    
    public var body: some View {
        Color.black
            .overlay {
                VStack(spacing: Spacing.xxl4) {
                    VStack(spacing: Spacing.s) {
                        Image(systemName: "exclamationmark.circle")
                        Text(.cameraNoPermissionsTitle)
                            .font(.title3Emphasized)
                        Text(.cameraNoPermissionsSubtitle)
                            .font(.subheadline)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
                    
                    Button(.cameraNoPermissionsCta, action: onSettings)
                        .buttonStyle(.filled)
                        .controlSize(.large)
                        .padding(.horizontal, Spacing.xl)
                        .readableContentMargins()
                }
                .foregroundStyle(.white)
            }
            .ignoresSafeArea()
    }
}

#Preview {
    NoAccessCameraView(onSettings: {})
}
