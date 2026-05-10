// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupConfigIcon: View {
    let kind: SyncServiceKind
    let size: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(kind: SyncServiceKind, size: CGFloat = 40) {
        self.kind = kind
        self.size = size
    }

    private var cornerRadius: CGFloat { 12 }

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
//            Image(systemName: "cloud.fill")
//                .font(.system(size: 33))
            Image(systemName: "externaldrive.fill")
                .renderingMode(.template)
                .font(.system(size: size * 0.5))
//                .foregroundStyle(colorScheme == .dark ? Color.neutral950 : .neutral50)
        case .s3:
            // AWS asset is a self-contained green tile — clip to the same corner radius.
            Image(.s3Icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: size * 0.5, height: size * 0.5)

//                .scaledToFit()
//                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(colorScheme == .dark ? .neutral800 : .neutral200, lineWidth: 0.5)
            .fill(.white)
//        switch kind {
//        case .iCloud:
//            Color.white
////                .fill(colorScheme == .dark ? .baseStatic0 : .clear)
//        case .webDAV:
//            Color.white
////            RoundedRectangle(cornerRadius: cornerRadius)
////                .fill(.accent)
//        case .s3:
//            Color.white
//        }
    }
}
