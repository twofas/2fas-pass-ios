// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let documentImageMaxHeight = 249.0
    static let stepProgess: Float = 0.8
}

struct VaultDecryptionKitView: View {

    @State
    var presenter: VaultDecryptionKitPresenter
        
    init(presenter: VaultDecryptionKitPresenter) {
        self.presenter = presenter
    }
    
    var body: some View {
        switch presenter.kind {
        case .onboarding:
            content
                .onboardingStepTopPadding()
                .onboardingStepProgress(Constants.stepProgess)
            
        case .settings:
            content
        }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            HeaderContentView(
                title: Text(.decryptionKitTitle),
                subtitle: Text(.decryptionKitDescription),
                icon: {
                    if presenter.kind != .onboarding {
                        Image(.lockFileHeaderIcon)
                    }
                }
            )
            .padding(.top, Spacing.l)
            
            VStack(spacing: Spacing.s) {
                Label(.decryptionKitStep1, systemImage: "arrow.down.circle.fill")
                Label(.decryptionKitStep2, systemImage: "printer.fill")
            }
            .padding(.top, Spacing.xl)
            .labelStyle(StepLabelStyle())
            
            Spacer(minLength: Spacing.xl)
            
            documentImage
                .resizable()
                .scaledToFit()
                .frame(maxHeight: Constants.documentImageMaxHeight)
            
            InfoToggle(
                icon: Image(.warningIcon),
                title: Text(.decryptionKitNoticeTitle),
                description: Text(.decryptionKitNoticeMsg),
                isOn: $presenter.isToggleOn
            )
            .disabled(presenter.isPDFSaving)
                        
            Button {
                presenter.onSaveRecoveryKit()
            } label: {
                Text(.decryptionKitCta)
                    .accessoryLoader(presenter.isPDFSaving)
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .disabled(presenter.savePDFDisabled)
            .allowsHitTesting(presenter.isPDFSaving == false)
            .padding(.top, Spacing.xll)
            .padding(.bottom, Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
        .slideToolbarTrailingItems {
            settingsButton
                .padding(.horizontal, Spacing.s)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                settingsButton
            }
        }
        .router(router: VaultDecryptionKitRouter(), destination: $presenter.destination)
        .readableContentMargins()
    }
    
    private var documentImage: Image {
        if presenter.includeMasterKey {
            Image(.vaultDecryptionKitDocumentSeedMasterkey)
        } else {
            Image(.vaultDecryptionKitDocumentSeed)
        }
    }

    private var settingsButton: some View {
        Button {
            presenter.onSettings()
        } label: {
            Image(systemName: "gearshape")
                .slideNavigationButtonLabel()
        }
    }
}

#Preview {
    NavigationStack {
        VaultDecryptionKitRouter.buildView(kind: .settings)
    }
}

public struct StepLabelStyle: LabelStyle {
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xs) {
            configuration.icon
                .foregroundStyle(.neutral500)
            configuration.title
                .foregroundStyle(.neutral600)
        }
    }
}
