// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct ViewLogsView: View {
    
    @State
    var presenter: ViewLogsPresenter
    
    @Environment(\.dismiss)
    private var dismiss
    
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
        .onDisappear {
            presenter.onDisappear()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(T.commonCancel.localizedKey) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presenter.onShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .router(router: ViewLogsRouter(), destination: $presenter.destination)
    }
    
    @ViewBuilder
    private var generating: some View {
        ProgressView()
            .controlSize(.large)
            .tint(nil)
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

#Preview {
    ViewLogsView(presenter: .init(interactor: ModuleInteractorFactory.shared.viewLogsModuleInteractor()))
}
