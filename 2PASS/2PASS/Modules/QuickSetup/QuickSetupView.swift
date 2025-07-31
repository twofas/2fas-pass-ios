// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let firstStepAppearDelay: TimeInterval = 0.3
    static let secondStepAppearDelay: TimeInterval = 0.45
    static let thirdStepAppearDelay: TimeInterval = 0.6
    static let buttonsAppearDelay: Duration = .milliseconds(900)
    static let buttonsAppearFeedbackDelay: Duration = .milliseconds(150)
}

struct QuickSetupView: View {
    
    @State
    var presenter: QuickSetupPresenter
    
    @State
    private var appearAnimation = false
    
    @State
    private var appearButtons = false
    
    @State
    private var appearCloseButton = false
    
    @State
    private var appearFeedback = false
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    header
                    
                    VStack(spacing: Spacing.s) {
                        StepView(
                            title: {
                                HStack(spacing: Spacing.s) {
                                    Text(T.quickSetupAutofillTitle.localizedKey)
                                    RecommendedLabel()
                                }
                            },
                            subtitle: Text(T.quickSetupAutofillDescription.localizedKey),
                            accessory: {
                                Toggle(isOn: $presenter.autofillIsEnabled, label: {})
                                    .layoutPriority(-1)
                            }
                        )
                        .stepAppearAnimation(appearAnimation, delay: Constants.firstStepAppearDelay)
                        
                        StepView(
                            title: {
                                HStack(spacing: Spacing.s) {
                                    Text(T.quickSetupIcloudSyncTitle.localizedKey)
                                    RecommendedLabel()
                                }
                            },
                            subtitle: Text(T.quickSetupIcloudSyncDescription.localizedKey),
                            accessory: {
                                Toggle(isOn: $presenter.iCloudSyncEnabled, label: {})
                                    .layoutPriority(-1)
                            }
                        )
                        .stepAppearAnimation(appearAnimation, delay: Constants.secondStepAppearDelay)
                        
                        securityTierStep
                            .stepAppearAnimation(appearAnimation, delay: Constants.thirdStepAppearDelay)
                    }
                    .padding(.top, Spacing.m)
                    .padding(.horizontal, Spacing.xll)
                    
                    importButtons
                        .padding(.top, Spacing.m)
                        .padding(.bottom, Spacing.xll)
                        .opacity(appearButtons ? 1 : 0)
                        .animation(.easeInOut, value: appearButtons)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            
            Button(T.commonClose.localizedKey) {
                presenter.onClose()
                dismiss()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(.horizontal, Spacing.xll)
            .padding(.bottom, Spacing.l)
            .opacity(appearCloseButton ? 1 : 0)
            .animation(.easeInOut, value: appearCloseButton)
        }
        .interactiveDismissDisabled()
        .tint(.brand500)
        .background(Color.base0)
        .router(router: QuickSetupRouter(), destination: $presenter.destination)
        .sensoryFeedback(.selection, trigger: appearFeedback)
        .toast(Text(T.quickSetupIcloudSyncFailure.localizedKey), isPresented: $presenter.showVaultSyncFailure, style: .failure)
        .task {
            await presenter.onAppear()
        }
        .onAppear {
            Task {
                appearAnimation = true
                try await Task.sleep(for: Constants.buttonsAppearDelay)
                appearButtons = true
                appearCloseButton = true
                try await Task.sleep(for: Constants.buttonsAppearFeedbackDelay)
                appearFeedback = true
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: Spacing.s) {
            Image(.quickSetupIcon)
                .padding(.bottom, Spacing.m)
                .padding(.top, Spacing.xll2)
            
            Text(T.quickSetupTitle.localizedKey)
                .font(.title1Emphasized)
                .foregroundStyle(.neutral950)
            
            Text(T.quickSetupSubtitle.localizedKey)
                .font(.subheadline)
                .foregroundStyle(.neutral600)
        }
        .padding(.horizontal, Spacing.xll)
    }
    
    private var securityTierStep: some View {
        StepView(
            title: Text(T.quickSetupSecurityTierTitle.localizedKey),
            subtitle: Text(T.quickSetupSecurityTierDescription.localizedKey),
            accessory: {},
            footer: {
                Divider()
                    .padding(.top, Spacing.xs)
                
                Button {
                    presenter.onChangeDefaultSecurityTier()
                } label: {
                    HStack(spacing: Spacing.s) {
                        Text(T.quickSetupSecurityTierDefaultLabel.localizedKey)
                            .font(.body)
                            .foregroundStyle(.neutral950)
                        
                        Spacer()
                        
                        Label {
                            Text(presenter.defaultSecurityTier.title.localizedKey)
                                .foregroundStyle(.neutral500)
                        } icon: {
                            presenter.defaultSecurityTier.icon
                                .renderingMode(.template)
                                .foregroundStyle(.accent)
                        }
                        .labelStyle(.rowValue)
                        
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.neutral400)
                    }
                    .contentShape(Rectangle())
                }
                .contentShape(Rectangle())
                .padding(.top, Spacing.xs)
                .buttonStyle(.plain)
            }
        )
    }
    
    private var importButtons: some View {
        VStack(spacing: Spacing.s) {
            Button {
                presenter.onImportItems()
            } label: {
                Label {
                    Text(T.quickSetupImportItemsCta.localizedKey)
                } icon: {
                    Image(.importItemsIcon)
                        .renderingMode(.template)
                }
            }
            
            Button {
                presenter.onTransferItems()
            } label: {
                Label {
                    Text(T.quickSetupTransferItemsCta.localizedKey)
                } icon: {
                    Image(.transferItemsIcon)
                        .renderingMode(.template)
                }
            }
        }
        .buttonStyle(.bezeledGray(fillSpace: false))
        .padding(.horizontal, Spacing.xll)
    }
}

private struct RecommendedLabel: View {
 
    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "info.circle.fill")
            Text(T.quickSetupRecommended.localizedKey)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.white)
        .padding(Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.brand500)
        }
    }
}

#Preview {
    NavigationStack {
        QuickSetupView(presenter: .init(interactor: ModuleInteractorFactory.shared.quickSetupModuleInteractor()))
    }
}
