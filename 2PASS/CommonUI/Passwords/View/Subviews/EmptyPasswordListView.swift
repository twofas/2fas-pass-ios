// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct EmptyPasswordListView: View {
    
    let onQuickSetup: Callback
    
    private var showQuickSetup: Bool = true
    
    init(onQuickSetup: @escaping Callback) {
        self.onQuickSetup = onQuickSetup
    }
    
    var body: some View {
        VStack {
            VStack {
                Spacer()
                
                VStack(spacing: Spacing.xll) {
                    Image(systemName: "lock.rectangle.stack")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 85, height: 85)
                        .foregroundStyle(.brand500)
                    
                    Text(T.homeEmptyTitle.localizedKey)
                        .font(.title2Emphasized)
                }
                
                Spacer()
            }
            
            Spacer()

            if showQuickSetup {
                Button {
                    onQuickSetup()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(T.homeEmptyImportCta.localizedKey)
                        Image(.quickSetupSmallIcon)
                            .renderingMode(.template)
                    }
                }
                .buttonStyle(.bezeledGray(fillSpace: false))
                .padding(.bottom, Spacing.xxl4)
            }
        }
    }
    
    func quickSetupHidden(_ hidden: Bool) -> some View {
        var instance = self
        instance.showQuickSetup = hidden == false
        return instance
    }
}

#Preview {
    EmptyPasswordListView(onQuickSetup: {})
}
