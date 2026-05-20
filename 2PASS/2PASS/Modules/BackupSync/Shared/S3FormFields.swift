// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

/// Sectioned S3 credential fields shared by the backup-config form (edit/add) and the
/// recovery S3 form. Renders three sections: endpoint + region + bucket, access keys
/// (with a "Load from CSV" header action), and a security toggle.
///
/// Edit-mode "changed" indicators are opt-in via per-field chainable modifiers. Forms
/// that have no original snapshot (recovery, fresh add) simply omit them.
///
/// ```
/// S3FormFields(
///     endpoint: $presenter.endpoint,
///     region: $presenter.region,
///     bucket: $presenter.bucket,
///     accessKeyId: $presenter.accessKeyId,
///     secretAccessKey: $presenter.secretAccessKey,
///     allowTLSOff: $presenter.allowTLSOff,
///     onLoadFromCSV: { presenter.onLoadFromCSV() }
/// )
/// .formFieldChanged(endpoint: presenter.endpointChanged)
/// .formFieldChanged(region: presenter.regionChanged)
/// .formFieldChanged(bucket: presenter.bucketChanged)
/// .formFieldChanged(accessKeyId: presenter.accessKeyIdChanged)
/// .formFieldChanged(secretAccessKey: presenter.secretAccessKeyChanged)
/// .formFieldChanged(allowTLSOff: presenter.allowTLSOffChanged)
/// ```
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

    /// Shared label width across the labeled rows (region, bucket) so the input columns
    /// stay aligned regardless of which label happens to be longer in the active locale.
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

    /// Lights the endpoint row's "changed from original" indicator.
    func formFieldChanged(endpoint flag: Bool) -> Self {
        var instance = self
        instance.endpointChanged = flag
        return instance
    }

    /// Lights the region row's "changed from original" indicator.
    func formFieldChanged(region flag: Bool) -> Self {
        var instance = self
        instance.regionChanged = flag
        return instance
    }

    /// Lights the bucket row's "changed from original" indicator.
    func formFieldChanged(bucket flag: Bool) -> Self {
        var instance = self
        instance.bucketChanged = flag
        return instance
    }

    /// Lights the access-key-ID row's "changed from original" indicator.
    func formFieldChanged(accessKeyId flag: Bool) -> Self {
        var instance = self
        instance.accessKeyIdChanged = flag
        return instance
    }

    /// Lights the secret-access-key row's "changed from original" indicator.
    func formFieldChanged(secretAccessKey flag: Bool) -> Self {
        var instance = self
        instance.secretAccessKeyChanged = flag
        return instance
    }

    /// Lights the allow-self-signed-certs row's "changed from original" indicator.
    func formFieldChanged(allowTLSOff flag: Bool) -> Self {
        var instance = self
        instance.allowTLSOffChanged = flag
        return instance
    }
}
