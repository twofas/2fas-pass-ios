// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct SecurityTierHelpView: View {
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    VStack(spacing: Spacing.l) {
                        Image(.tiersHelpHeader)
                            .padding(.vertical, Spacing.l)
                        
                        Text(.securityTiersHelpTitle)
                            .font(.title1Emphasized)
                            .foregroundStyle(.neutral950)
                        
                        Text(.securityTiersHelpSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.neutral600)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Spacing.l)
                    
                    section {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            sectionTitle {
                                Text(.securityTiersHelpLocalFirstSectionTitle)
                            }
                            
                            sectionDescription {
                                Text(.securityTiersHelpLocalFirstSectionSubtitle)
                            }
                        }
                        
                        highlight {
                            VStack(alignment: .leading, spacing: 0) {
                                sectionHeadline {
                                    Text(.securityTiersHelpLocalFirstSectionFigureTitle)
                                }
                                
                                Image(.securityTiersLevelsFigure)
                            }
                        }
                    }
                    
                    section {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            sectionTitle {
                                Text(.securityTiersHelpTiersSectionTitle)
                            }
                            
                            sectionDescription {
                                Text(.securityTiersHelpTiersSectionSubtitle)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: Spacing.l) {
                            tierDescription(
                                title: Text(.securityTiersHelpTiersSecretTitle),
                                description: Text(.securityTiersHelpTiersSecretSubtitle),
                                figure: Image(.secretTierFigure)
                            )
                            
                            tierDescription(
                                title: Text(.securityTiersHelpTiersHighlySecretTitle),
                                description: Text(.securityTiersHelpTiersHighlySecretSubtitle),
                                figure: Image(.highlySecretTierFigure)
                            )
                            
                            tierDescription(
                                title: Text(.securityTiersHelpTiersTopSecretTitle),
                                description: Text(.securityTiersHelpTiersTopSecretSubtitle),
                                figure: Image(.topSecretTierFigure)
                            )
                        }
                    }
                    
                    section {
                        sectionTitle {
                            Text(.securityTiersHelpLayersSectionTitle)
                        }
                        
                        layerDescription(
                            title: Text(.securityTiersHelpTiersLayersE2EeTitle),
                            description: Text(.securityTiersHelpTiersLayersE2EeSubtitle)
                        )
                        
                        layerDescription(
                            title: Text(.securityTiersHelpTiersLayersSecureEnclaveTitle),
                            description: Text(.securityTiersHelpTiersLayersSecureEnclaveSubtitle)
                        )
                        
                        layerDescription(
                            title: Text(.securityTiersHelpTiersLayersAdpTitle),
                            description: Text(.securityTiersHelpTiersLayersAdpSubtitle)
                        )
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        dismiss()
                    }
                }
            }
            .background(
                Color(UIColor.systemGroupedBackground)
            )
        }
    }
    
    private func section(@ViewBuilder content: () -> some View) -> some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.l) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func sectionTitle(@ViewBuilder content: () -> some View) -> some View {
        content()
            .font(.title3Emphasized)
            .foregroundStyle(.neutral950)
    }
    
    private func sectionHeadline(@ViewBuilder content: () -> some View) -> some View {
        content()
            .font(.headlineEmphasized)
            .foregroundStyle(.neutral950)
    }
    
    private func sectionDescription(@ViewBuilder content: () -> some View) -> some View {
        content()
            .font(.footnote)
            .foregroundStyle(.neutral600)
    }
    
    private func highlight(@ViewBuilder content: () -> some View) -> some View {
        HStack {
            content()
            Spacer(minLength: 0)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func tierDescription(title: Text, description: Text, figure: Image) -> some View {
        highlight {
            VStack(alignment: .leading, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    sectionHeadline {
                        title
                    }
                    sectionDescription {
                        description
                    }
                }
                
                figure
            }
        }
    }
    
    private func layerDescription(title: Text, description: Text) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionHeadline {
                title
            }
            
            sectionDescription {
                description
            }
        }
    }
}

#Preview {
    SecurityTierHelpView()
}
