// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct EventLogView: View {
    @Bindable
    var presenter: EventLogPresenter
    
    var body: some View {
        ZStack {
            if presenter.logs.isEmpty {
                generating
            } else {
                List {
                    ForEach(presenter.logs, id: \.self) { log in
                        cell(date: log.date, icons: log.icons, content: log.text)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    presenter.onCopy()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                
                Button {
                    presenter.onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
    
    @ViewBuilder
    private var generating: some View {
        Text("Generating ..." as String)
            .font(.title3)
            .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
    }
    
    @ViewBuilder
    private func cell(date: String, icons: String, content: String) -> some View {
        VStack(spacing: Spacing.l) {
            HStack(alignment: .center, spacing: Spacing.m) {
                Text(verbatim: date)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
                Spacer()
                Text(verbatim: icons)
                    .font(.caption2)
                    .frame(alignment: .trailing)
            }
            HStack(alignment: .center, spacing: 0) {
                Text(verbatim: content)
                    .multilineTextAlignment(.leading)
                    .font(.caption)
                    .monospaced()
                    .onTapGesture(count: 2) {
                        UIPasteboard.general.string = content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
        }
    }
}

