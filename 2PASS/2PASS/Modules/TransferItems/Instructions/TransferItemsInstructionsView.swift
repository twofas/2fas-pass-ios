// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Foundation
import CommonUI

struct TransferItemsInstructionsView: View {
    
    @State var presenter: TransferItemsInstructionsPresenter
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(Text(.transferInstructionsHeader(presenter.service.name))) {
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
                    title: { Text(.transferInstructionsHeader(presenter.service.name)) },
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
                        Text(.transferInstructionsCtaOnepassword)
                    case .bitWarden:
                        Text(.transferInstructionsCtaBitwarden)
                    case .protonPass:
                        Text(.transferInstructionsCtaProtonPass)
                    case .dashlaneMobile:
                        Text(.transferInstructionsCtaDashlaneMobile)
                    case .keePass:
                        Text(.transferInstructionsCtaKeepass)
                    case .keePassXC:
                        Text(.transferInstructionsCtaKeepassxc)
                    default:
                        if presenter.service.allowedContentTypes.count > 1 {
                            Text(.transferInstructionsCtaGeneric)
                        } else if let contentType = presenter.service.allowedContentTypes.first {
                            switch contentType {
                            case .json:
                                Text(.transferInstructionsCtaJson)
                            case .zip:
                                Text(.transferInstructionsCtaZip)
                            case .commaSeparatedText:
                                Text(.transferInstructionsCtaCsv)
                            default:
                                Text(.transferInstructionsCtaGeneric)
                            }
                        } else {
                            Text(.transferInstructionsCtaGeneric)
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
                Text(step)
                Spacer()
            }
            .foregroundStyle(.neutral950)
            .font(.footnote)
            .padding(.vertical, Spacing.xs)
        }
    }
    
    private var instructionsSteps: [AttributedString] {
        let resource: LocalizedStringResource = {
            switch presenter.service {
            case .bitWarden:
                .transferInstructionsBitwarden
            case .chrome:
                .transferInstructionsChrome
            case .dashlaneMobile:
                .transferInstructionsDashlaneMobile
            case .dashlaneDesktop:
                .transferInstructionsDashlanePc
            case .lastPass:
                .transferInstructionsLastpass
            case .onePassword:
                .transferInstructionsOnepassword
            case .protonPass:
                .transferInstructionsProtonpass
            case .applePasswordsDesktop:
                .transferInstructionsApplePasswordsPc
            case .applePasswordsMobile:
                .transferInstructionsApplePasswordsMobile
            case .firefox:
                .transferInstructionsFirefox
            case .keePassXC:
                .transferInstructionsKeepassxc
            case .keePass:
                .transferInstructionsKeepass
            case .microsoftEdge:
                .transferInstructionsMicrosoftEdge
            case .enpass:
                .transferInstructionsEnpass
            case .keeper:
                .transferInstructionsKeeper
            }
        }()
        let input = String(localized: resource)
        return input.components(separatedBy: "\n\n").map { step in
            (try? AttributedString(markdown: step)) ?? AttributedString(step)
        }
    }
    
    private var instructionsAdditionalInfo: Text? {
        switch presenter.service {
        case .onePassword:
            Text(.transferInstructionsAdditionalInfoOnepassword)
        case .bitWarden:
            Text(.transferInstructionsAdditionalInfoBitwarden)
        case .keePass:
            Text(.transferInstructionsAdditionalInfoKeepass)
        case .keePassXC:
            Text(.transferInstructionsAdditionalInfoKeepassxc)
        case .protonPass:
            Text(.transferInstructionsAdditionalInfoProtonPass)
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
