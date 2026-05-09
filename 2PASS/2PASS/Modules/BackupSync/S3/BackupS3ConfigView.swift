// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupS3ConfigView: View {

    @State
    var presenter: BackupS3ConfigPresenter

    @Environment(\.dismiss) private var dismiss
    @State private var fieldLabelWidth: CGFloat?
    @State private var isDiscardConfirmationPresented = false

    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(.backupConfigsRowS3Title) {
                Section {
                    TextField("https://s3.example.com" as String, text: $presenter.endpoint)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .formFieldChanged(presenter.endpointChanged)

                    LabeledInput(label: String(localized: .s3Region), fieldWidth: $fieldLabelWidth) {
                        TextField("us-east-1" as String, text: $presenter.region)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.leading, Spacing.s)
                    }
                    .formFieldChanged(presenter.regionChanged)

                    LabeledInput(label: String(localized: .s3Bucket), fieldWidth: $fieldLabelWidth) {
                        TextField("my-bucket" as String, text: $presenter.bucket)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.leading, Spacing.s)
                    }
                    .formFieldChanged(presenter.bucketChanged)
                }

                Section {
                    TextField(String(localized: .s3AccessKeyId), text: $presenter.accessKeyId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .formFieldChanged(presenter.accessKeyIdChanged)

                    SecureInput(label: .s3SecretAccessKey, value: $presenter.secretAccessKey)
                        .formFieldChanged(presenter.secretAccessKeyChanged)
                } header: {
                    HStack {
                        Text(.s3Credentials)
                        Spacer()
                        Button(String(localized: .s3LoadFromCsvButton)) {
                            presenter.onLoadFromCSV()
                        }
                        .font(.calloutEmphasized)
                    }
                }

                Section(.s3Security) {
                    Toggle(.s3AllowUntrustedCertificates, isOn: $presenter.allowTLSOff)
                        .tint(.accentColor)
                        .formFieldChanged(presenter.allowTLSOffChanged)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .disabled(presenter.isTesting)
        .sensoryFeedback(.success, trigger: presenter.successFeedbackTrigger)
        .sensoryFeedback(.error, trigger: presenter.failureFeedbackTrigger)
        .router(router: BackupS3ConfigRouter(), destination: $presenter.destination)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: Spacing.s) {
                    Image(.s3Icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(.backupConfigsRowS3Title)
                        .font(.headline)
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                ToolbarCancelButton {
                    hideKeyboard()
                    if presenter.hasUnsavedChanges {
                        isDiscardConfirmationPresented = true
                    } else {
                        dismiss()
                    }
                }
                .confirmationDialog(
                    Text(.loginUnsavedChangesDialogTitle),
                    isPresented: $isDiscardConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) {
                        hideKeyboard()
                        dismiss()
                    } label: {
                        Text(.commonDiscardChanges)
                    }
                } message: {
                    Text(.loginUnsavedChangesDialogDescription)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if presenter.isTesting {
                    ProgressView()
                } else if #available(iOS 26, *) {
                    Button(role: .confirm) {
                        hideKeyboard()
                        presenter.onSave()
                    }
                    .disabled(!presenter.canSave)
                } else {
                    Button {
                        hideKeyboard()
                        presenter.onSave()
                    } label: {
                        Text(presenter.isEditMode ? .commonSave : .commonDone)
                    }
                    .disabled(!presenter.canSave)
                }
            }
        }
        .background(
            DragDismissAttemptCatcher(isEnabled: presenter.hasUnsavedChanges) {
                isDiscardConfirmationPresented = true
            }
        )
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.cancelTest()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.hideKeyboard()
    }
}

/// UIKit bridge that fires `onAttempt` when the user tries to swipe-dismiss a sheet whose
/// content has unsaved changes. Sets `isModalInPresentation = true` on the sheet's
/// presentation VC (precondition for `presentationControllerDidAttemptToDismiss` callbacks)
/// and chains its delegate slot to SwiftUI's original delegate so sheet dismiss tracking,
/// detent updates, etc. continue to work.
private struct DragDismissAttemptCatcher: UIViewControllerRepresentable {
    let isEnabled: Bool
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.update(isEnabled: isEnabled, onAttempt: onAttempt)
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.uninstall()
    }

    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        private var onAttempt: () -> Void = {}
        private var isEnabled = false
        private weak var presentedTarget: UIViewController?
        private weak var originalDelegate: (any UIAdaptivePresentationControllerDelegate)?

        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            installIfNeeded()
            applyModalState()
        }

        func update(isEnabled: Bool, onAttempt: @escaping () -> Void) {
            self.onAttempt = onAttempt
            self.isEnabled = isEnabled
            installIfNeeded()
            applyModalState()
        }

        func uninstall() {
            if let target = presentedTarget,
               let presentationController = target.presentationController,
               presentationController.delegate === self {
                presentationController.delegate = originalDelegate
            }
            presentedTarget?.isModalInPresentation = false
            presentedTarget = nil
            originalDelegate = nil
        }

        private func installIfNeeded() {
            guard presentedTarget == nil else { return }
            guard let target = findPresentedAncestor() else { return }
            presentedTarget = target
            if let presentationController = target.presentationController {
                originalDelegate = presentationController.delegate
                presentationController.delegate = self
            }
        }

        private func applyModalState() {
            presentedTarget?.isModalInPresentation = isEnabled
        }

        /// Walks the parent chain to find the topmost ancestor that's actually presented as
        /// a sheet — its `presentationController` is the one whose dismiss-attempt callback
        /// we want to receive.
        private func findPresentedAncestor() -> UIViewController? {
            var current: UIViewController? = parent
            var lastPresented: UIViewController? = nil
            while let viewController = current {
                if viewController.presentingViewController != nil {
                    lastPresented = viewController
                }
                current = viewController.parent
            }
            return lastPresented
        }

        // MARK: - Delegate forwarding

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            originalDelegate
        }

        // MARK: - UIAdaptivePresentationControllerDelegate

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttempt()
            originalDelegate?.presentationControllerDidAttemptToDismiss?(presentationController)
        }
    }
}

#Preview {
    BackupS3ConfigRouter.buildView(configID: nil)
}
