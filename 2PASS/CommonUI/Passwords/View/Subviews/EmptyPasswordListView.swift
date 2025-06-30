// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct EmptyPasswordListView: View {
    let onImport: Callback
    
    var body: some View {
        VStack {
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "lock.rectangle.stack")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 85, height: 85)
                        .foregroundStyle(Asset.inactiveColor.swiftUIColor)
                    
                    VStack(spacing: 8) {
                        Text(T.homeEmptyTitle.localizedKey)
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("home_empty_msg_ios \(Text(Image(systemName: "plus.circle.fill")))")
                            .font(.subheadline)
                            .foregroundStyle(Asset.inactiveColor.swiftUIColor)
                    }
                }
                
                Spacer()
            }
            
            Spacer()
            
            VStack(spacing: 0) {
                Text(T.homeEmptyImportDescription.localizedKey)
                    .foregroundStyle(Asset.inactiveColor.swiftUIColor)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                
                Button(T.homeEmptyImportCta.localizedKey)  {
                    onImport()
                }
                .buttonStyle(.twofasBorderless)
            }
            .frame(height: 112)
            .padding(.horizontal, Spacing.xll)
        }
    }
}

#Preview {
    EmptyPasswordListView(onImport: {})
}
