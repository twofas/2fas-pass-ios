// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupServiceIcon: View {
    let kind: BackupSyncService

    @Environment(\.controlSize) private var controlSize
    @Environment(\.colorScheme) private var colorScheme

    init(kind: BackupSyncService) {
        self.kind = kind
    }

    private var size: CGFloat {
        switch controlSize {
        case .mini, .small: 32
        case .regular: 40
        case .large, .extraLarge: 64
        @unknown default: 40
        }
    }

    private var cornerRadius: CGFloat {
        switch controlSize {
        case .mini, .small: 6
        case .regular: 8
        case .large, .extraLarge: 12
        @unknown default: 8
        }
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .background(background)
            .foregroundStyle(.accent)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .iCloud:
            Image(.iCloudLogo)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
        case .webDAV:
            Image(systemName: "externaldrive.fill")
                .renderingMode(.template)
                .font(.system(size: size * 0.5))
        case .s3:
            Image(.s3Icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: size * 0.5, height: size * 0.5)
        }
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(colorScheme == .dark ? .neutral800 : .neutral200, lineWidth: 0.5)
            .fill(.white)
    }
}
