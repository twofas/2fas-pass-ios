// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct WebDAVFormFields: View {

    @Binding var url: String
    @Binding var username: String
    @Binding var password: String
    @Binding var allowTLSOff: Bool

    private var urlChanged = false
    private var usernameChanged = false
    private var passwordChanged = false
    private var allowTLSOffChanged = false

    init(
        url: Binding<String>,
        username: Binding<String>,
        password: Binding<String>,
        allowTLSOff: Binding<Bool>
    ) {
        self._url = url
        self._username = username
        self._password = password
        self._allowTLSOff = allowTLSOff
    }

    var body: some View {
        Section {
            TextField("https://webdav.example.com" as String, text: $url)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(.URL)
                .formFieldChanged(urlChanged)
        }

        Section(.webdavCredentials) {
            TextField(String(localized: .webdavUsername), text: $username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                .formFieldChanged(usernameChanged)

            SecureInput(label: .webdavPassword, value: $password)
                .formFieldChanged(passwordChanged)
        }

        Section(.backupConfigsSecurityHeader) {
            Toggle(.backupConfigsAllowUntrustedCertificates, isOn: $allowTLSOff)
                .tint(.accent)
                .formFieldChanged(allowTLSOffChanged)
        }
    }

    func formFieldChanged(url flag: Bool) -> Self {
        var instance = self
        instance.urlChanged = flag
        return instance
    }

    func formFieldChanged(username flag: Bool) -> Self {
        var instance = self
        instance.usernameChanged = flag
        return instance
    }

    func formFieldChanged(password flag: Bool) -> Self {
        var instance = self
        instance.passwordChanged = flag
        return instance
    }

    func formFieldChanged(allowTLSOff flag: Bool) -> Self {
        var instance = self
        instance.allowTLSOffChanged = flag
        return instance
    }
}
