// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

/// Sectioned WebDAV credential fields shared by the backup-config form (edit/add) and
/// the recovery WebDAV form. Renders three sections: server URL, credentials, and a
/// security toggle for self-signed certs.
///
/// Edit-mode "changed" indicators are opt-in via per-field chainable modifiers. Forms
/// that have no original snapshot (recovery, fresh add) simply omit them.
///
/// ```
/// WebDAVFormFields(
///     url: $presenter.url,
///     username: $presenter.username,
///     password: $presenter.password,
///     allowTLSOff: $presenter.allowTLSOff
/// )
/// .formFieldChanged(url: presenter.urlChanged)
/// .formFieldChanged(username: presenter.usernameChanged)
/// .formFieldChanged(password: presenter.passwordChanged)
/// .formFieldChanged(allowTLSOff: presenter.allowTLSOffChanged)
/// ```
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

        Section(.backupConfigsSecurity) {
            Toggle(.backupConfigsAllowUntrustedCertificates, isOn: $allowTLSOff)
                .tint(.accent)
                .formFieldChanged(allowTLSOffChanged)
        }
    }

    /// Lights the URL row's "changed from original" indicator.
    func formFieldChanged(url flag: Bool) -> Self {
        var instance = self
        instance.urlChanged = flag
        return instance
    }

    /// Lights the username row's "changed from original" indicator.
    func formFieldChanged(username flag: Bool) -> Self {
        var instance = self
        instance.usernameChanged = flag
        return instance
    }

    /// Lights the password row's "changed from original" indicator.
    func formFieldChanged(password flag: Bool) -> Self {
        var instance = self
        instance.passwordChanged = flag
        return instance
    }

    /// Lights the allow-self-signed-certs row's "changed from original" indicator.
    func formFieldChanged(allowTLSOff flag: Bool) -> Self {
        var instance = self
        instance.allowTLSOffChanged = flag
        return instance
    }
}
