// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct AppStateView: View {

    @State
    var presenter: AppStatePresenter
    
    var body: some View {
        List {
            ForEach(presenter.entries, id: \.self) { entry in
                HStack(alignment: .center, spacing: Spacing.m) {
                    if entry.isAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.red)
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text(entry.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Asset.mainTextColor.swiftUIColor)
                        if let value = entry.value {
                            Text(value)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
                        } else {
                            Text(verbatim: "<none>")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Asset.labelTertiaryColor.swiftUIColor)
                        }
                    }
                    
                    Spacer()
                }
                .onTapGesture(count: 2) {
                    if let value = entry.value {
                        UIPasteboard.general.string = value
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            presenter.onAppear()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presenter.onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}
