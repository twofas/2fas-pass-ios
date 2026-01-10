// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct SecurityTierPickerView: View {
    
    public init(selected: Binding<ItemProtectionLevel>) {
        self._selected = selected
    }
    
    @Binding
    var selected: ItemProtectionLevel
    
    @State
    private var showHelp: Bool = false
    
    public var body: some View {
        Section {
            Picker(selection: $selected) {
                ForEach(ItemProtectionLevel.allCases, id: \.self) { option in
                    HStack(spacing: Spacing.m) {
                        option.icon
                            .renderingMode(.template)
                            .foregroundStyle(.brand500)
                        
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(option.title)
                                .font(.body)
                                .foregroundStyle(.neutral950)
                            
                            Text(option.description)
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
            Text(.settingsHeaderProtectionLevel)
                .padding(.top, Spacing.m)
        } footer: {
            Text(.securityTypeModalDescription)
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
                    
                    Text(.settingsProtectionLevelHelp)
                        .foregroundStyle(.neutral950)
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            SecurityTierHelpView()
        }
    }
}
