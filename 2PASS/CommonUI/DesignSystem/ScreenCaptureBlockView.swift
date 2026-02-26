// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct ScreenCaptureBlockView: View {

    public init() {}

    public var body: some View {
        VStack(spacing: Spacing.l) {
            Image(.smallShield)

            Text(.blockScreenRecordingTitle)
                .font(.title2Emphasized)
                .foregroundStyle(.primary)

            Text(.blockScreenRecordingDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xll3)
        .readableContentMargins()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ScreenCaptureBlockView()
}
