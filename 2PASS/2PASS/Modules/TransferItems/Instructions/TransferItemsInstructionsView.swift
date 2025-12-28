// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct TransferItemsInstructionsView: View {
    
    @State var presenter: TransferItemsInstructionsPresenter
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(Text(T.transferInstructionsHeader(presenter.service.name).localizedKey)) {
                Section {
                    instructions
                }
                
                if let instructionsAdditionalInfo {
                    Section {
                        instructionsAdditionalInfo
                            .foregroundStyle(.neutral950)
                            .font(.footnote)
                    }
                }
                
            } header: {
                SettingsHeaderView(
                    icon: { SettingsIconView(icon: presenter.service.settingsIcon) },
                    title: { Text(T.transferInstructionsHeader(presenter.service.name).localizedKey) },
                    description: {}
                )
                .settingsIconStyle(.border)
            }
            .listSectionSpacing(Spacing.l)
            
            Button {
                presenter.onUploadFile()
            } label: {
                Group {
                    switch presenter.service {
                    case .onePassword:
                        Text(T.transferInstructionsCtaOnepassword.localizedKey)
                    case .bitWarden:
                        Text(T.transferInstructionsCtaBitwarden.localizedKey)
                    case .protonPass:
                        Text(T.transferInstructionsCtaProtonPass.localizedKey)
                    case .dashlaneMobile:
                        Text(T.transferInstructionsCtaDashlaneMobile.localizedKey)
                    default:
                        if presenter.service.allowedContentTypes.count > 1 {
                            Text(T.transferInstructionsCtaGeneric.localizedKey)
                        } else if let contentType = presenter.service.allowedContentTypes.first {
                            switch contentType {
                            case .json:
                                Text(T.transferInstructionsCtaJson.localizedKey)
                            case .zip:
                                Text(T.transferInstructionsCtaZip.localizedKey)
                            case .commaSeparatedText:
                                Text(T.transferInstructionsCtaCsv.localizedKey)
                            default:
                                Text(T.transferInstructionsCtaGeneric.localizedKey)
                            }
                        } else {
                            Text(T.transferInstructionsCtaGeneric.localizedKey)
                        }
                    }
                }
                .accessoryLoader(presenter.isUploadingFile)
            }
            .allowsHitTesting(presenter.isUploadingFile == false)
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .router(router: TransferItemsInstructionsRouter(), destination: $presenter.destination)
    }
    
    @ViewBuilder
    private var instructions: some View {
        ForEach(Array(instructionsSteps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top) {
                Text("\(index + 1).")
                Text(step.localizedKey)
                Spacer()
            }
            .foregroundStyle(.neutral950)
            .font(.footnote)
            .padding(.vertical, Spacing.xs)
        }
    }
    
    private var instructionsSteps: [String] {
        let input = {
            switch presenter.service {
            case .bitWarden:
                T.transferInstructionsBitwarden
            case .chrome:
                T.transferInstructionsChrome
            case .dashlaneMobile:
                T.transferInstructionsDashlaneMobile
            case .dashlaneDesktop:
                T.transferInstructionsDashlanePc
            case .lastPass:
                T.transferInstructionsLastpass
            case .onePassword:
                T.transferInstructionsOnepassword
            case .protonPass:
                T.transferInstructionsProtonpass
            case .applePasswordsDesktop:
                T.transferInstructionsApplePasswordsPc
            case .applePasswordsMobile:
                T.transferInstructionsApplePasswordsMobile
            case .firefox:
                T.transferInstructionsFirefox
            case .keePassXC:
                T.transferInstructionsKeepassxc
            case .keePass:
                T.transferInstructionsKeepass
            case .microsoftEdge:
                T.transferInstructionsMicrosoftEdge
            case .enpass:
                T.transferInstructionsEnpass
            case .keeper:
                T.transferInstructionsKeeper
            }
        }()
        return input.components(separatedBy: "\n\n")
    }
    
    private var instructionsAdditionalInfo: Text? {
        switch presenter.service {
        case .onePassword:
            Text(T.transferInstructionsAdditionalInfoOnepassword.localizedKey)
        case .bitWarden:
            Text(T.transferInstructionsAdditionalInfoBitwarden.localizedKey)
        case .protonPass:
            Text(T.transferInstructionsAdditionalInfoProtonPass.localizedKey)
        default:
            nil
        }
    }
}

#Preview {
    NavigationStack {
        TransferItemsInstructionsView(
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.transferItemsInstructionsModuleInteractor(service: .bitWarden),
                onClose: {}
            )
        )
    }
}
