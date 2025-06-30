// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct SecurityTierPickerView: View {
    
    public init(selected: Binding<PasswordProtectionLevel>) {
        self._selected = selected
    }
    
    @Binding
    var selected: PasswordProtectionLevel
    
    @State
    private var showHelp: Bool = false
    
    public var body: some View {
        Section {
            Picker(selection: $selected) {
                ForEach(PasswordProtectionLevel.allCases, id: \.self) { option in
                    HStack(spacing: Spacing.m) {
                        option.icon
                            .renderingMode(.template)
                            .foregroundStyle(.brand500)
                        
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(option.title.localizedKey)
                                .font(.body)
                                .foregroundStyle(.neutral950)
                            
                            Text(option.description.localizedKey)
                                .font(.footnote)
                                .foregroundStyle(.neutral500)
                        }
                    }
                    .tag(option)
                }
            } label: {}
            .pickerStyle(.inline)
            .listRowInsets(EdgeInsets(top: Spacing.m, leading: Spacing.m, bottom: Spacing.m, trailing: Spacing.m))
        } header: {
            Text(T.settingsHeaderProtectionLevel.localizedKey)
                .padding(.top, Spacing.m)
        } footer: {
            Text(T.securityTypeModalDescription.localizedKey)
                .font(.caption)
                .foregroundStyle(.neutral600)
                .lineSpacing(2)
                .padding(.top, 4)
        }
        
        Section {
            Button {
                showHelp = true
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "lightbulb")
                        .frame(width: 24, height: 24)
                    
                    Text(T.settingsProtectionLevelHelp.localizedKey)
                        .foregroundStyle(.neutral950)
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            SecurityTierHelpView()
        }
    }
}
