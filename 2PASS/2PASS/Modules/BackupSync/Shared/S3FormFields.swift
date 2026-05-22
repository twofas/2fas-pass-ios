// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

/// Sectioned S3 credential fields shared by the config editor and the recovery form.
/// Edit-mode "changed" indicators are opt-in via the per-field `formFieldChanged(_:)`
/// modifiers below; forms without an original snapshot just omit them.
struct S3FormFields: View {

    @Binding var endpoint: String
    @Binding var region: String
    @Binding var bucket: String
    @Binding var accessKeyId: String
    @Binding var secretAccessKey: String
    @Binding var allowTLSOff: Bool

    private let onLoadFromCSV: () -> Void

    private var endpointChanged = false
    private var regionChanged = false
    private var bucketChanged = false
    private var accessKeyIdChanged = false
    private var secretAccessKeyChanged = false
    private var allowTLSOffChanged = false

    /// Shared label width across labeled rows so input columns stay aligned across locales.
    @State private var fieldLabelWidth: CGFloat?

    init(
        endpoint: Binding<String>,
        region: Binding<String>,
        bucket: Binding<String>,
        accessKeyId: Binding<String>,
        secretAccessKey: Binding<String>,
        allowTLSOff: Binding<Bool>,
        onLoadFromCSV: @escaping () -> Void
    ) {
        self._endpoint = endpoint
        self._region = region
        self._bucket = bucket
        self._accessKeyId = accessKeyId
        self._secretAccessKey = secretAccessKey
        self._allowTLSOff = allowTLSOff
        self.onLoadFromCSV = onLoadFromCSV
    }

    var body: some View {
        Section {
            TextField("https://s3.example.com" as String, text: $endpoint)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(.URL)
                .formFieldChanged(endpointChanged)

            LabeledInput(label: String(localized: .s3Region), fieldWidth: $fieldLabelWidth) {
                TextField("us-east-1" as String, text: $region)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.leading, Spacing.s)
            }
            .formFieldChanged(regionChanged)

            LabeledInput(label: String(localized: .s3Bucket), fieldWidth: $fieldLabelWidth) {
                TextField("my-bucket" as String, text: $bucket)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.leading, Spacing.s)
            }
            .formFieldChanged(bucketChanged)
        }

        Section {
            TextField(String(localized: .s3AccessKeyId), text: $accessKeyId)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .formFieldChanged(accessKeyIdChanged)

            SecureInput(label: .s3SecretAccessKey, value: $secretAccessKey)
                .formFieldChanged(secretAccessKeyChanged)
        } header: {
            HStack {
                Text(.s3Credentials)
                Spacer()
                Button(String(localized: .s3LoadFromCsvCta)) {
                    onLoadFromCSV()
                }
                .font(.calloutEmphasized)
            }
        }

        Section(.backupConfigsSecurityHeader) {
            Toggle(.backupConfigsAllowUntrustedCertificates, isOn: $allowTLSOff)
                .tint(.accent)
                .formFieldChanged(allowTLSOffChanged)
        }
    }

    func formFieldChanged(endpoint flag: Bool) -> Self {
        var instance = self
        instance.endpointChanged = flag
        return instance
    }

    func formFieldChanged(region flag: Bool) -> Self {
        var instance = self
        instance.regionChanged = flag
        return instance
    }

    func formFieldChanged(bucket flag: Bool) -> Self {
        var instance = self
        instance.bucketChanged = flag
        return instance
    }

    func formFieldChanged(accessKeyId flag: Bool) -> Self {
        var instance = self
        instance.accessKeyIdChanged = flag
        return instance
    }

    func formFieldChanged(secretAccessKey flag: Bool) -> Self {
        var instance = self
        instance.secretAccessKeyChanged = flag
        return instance
    }

    func formFieldChanged(allowTLSOff flag: Bool) -> Self {
        var instance = self
        instance.allowTLSOffChanged = flag
        return instance
    }
}
