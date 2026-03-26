// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct PasskeyRegistrationView: View {

    let presenter: AutoFillRootPresenter

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Create Passkey")
                        .font(.title2.bold())

                    if let rpID = presenter.passkeyRegistrationRpID {
                        Text(rpID)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if let userName = presenter.passkeyRegistrationUserName, !userName.isEmpty {
                        Text(userName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        presenter.completePasskeyRegistration()
                    } label: {
                        Text("Create Passkey")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        presenter.onCancel()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        presenter.onCancel()
                    }
                }
            }
        }
    }
}
