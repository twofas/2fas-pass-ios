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
                        
                        Text(T.securityTiersHelpTitle.localizedKey)
                            .font(.title1Emphasized)
                            .foregroundStyle(.neutral950)
                        
                        Text(T.securityTiersHelpSubtitle.localizedKey)
                            .font(.subheadline)
                            .foregroundStyle(.neutral600)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Spacing.l)
                    
                    section {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            sectionTitle {
                                Text(T.securityTiersHelpLocalFirstSectionTitle.localizedKey)
                            }
                            
                            sectionDescription {
                                Text(T.securityTiersHelpLocalFirstSectionSubtitle.localizedKey)
                            }
                        }
                        
                        highlight {
                            VStack(alignment: .leading, spacing: 0) {
                                sectionHeadline {
                                    Text(T.securityTiersHelpLocalFirstSectionFigureTitle.localizedKey)
                                }
                                
                                Image(.securityTiersLevelsFigure)
                            }
                        }
                    }
                    
                    section {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            sectionTitle {
                                Text(T.securityTiersHelpTiersSectionTitle.localizedKey)
                            }
                            
                            sectionDescription {
                                Text(T.securityTiersHelpTiersSectionSubtitle.localizedKey)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: Spacing.l) {
                            tierDescription(
                                title: Text(T.securityTiersHelpTiersSecretTitle.localizedKey),
                                description: Text(T.securityTiersHelpTiersSecretSubtitle.localizedKey),
                                figure: Image(.secretTierFigure)
                            )
                            
                            tierDescription(
                                title: Text(T.securityTiersHelpTiersHighlySecretTitle.localizedKey),
                                description: Text(T.securityTiersHelpTiersHighlySecretSubtitle.localizedKey),
                                figure: Image(.highlySecretTierFigure)
                            )
                            
                            tierDescription(
                                title: Text(T.securityTiersHelpTiersTopSecretTitle.localizedKey),
                                description: Text(T.securityTiersHelpTiersTopSecretSubtitle.localizedKey),
                                figure: Image(.topSecretTierFigure)
                            )
                        }
                    }
                    
                    section {
                        sectionTitle {
                            Text(T.securityTiersHelpLayersSectionTitle.localizedKey)
                        }
                        
                        layerDescription(
                            title: Text(T.securityTiersHelpTiersLayersE2eeTitle.localizedKey),
                            description: Text(T.securityTiersHelpTiersLayersE2eeSubtitle.localizedKey),
                        )
                        
                        layerDescription(
                            title: Text(T.securityTiersHelpTiersLayersSecureEnclaveTitle.localizedKey),
                            description: Text(T.securityTiersHelpTiersLayersSecureEnclaveSubtitle.localizedKey),
                        )
                        
                        layerDescription(
                            title: Text(T.securityTiersHelpTiersLayersAdpTitle.localizedKey),
                            description: Text(T.securityTiersHelpTiersLayersAdpSubtitle.localizedKey),
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
