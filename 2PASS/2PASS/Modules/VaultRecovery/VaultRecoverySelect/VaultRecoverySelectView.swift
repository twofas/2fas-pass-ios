// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import PhotosUI
import Common
import CommonUI

struct VaultRecoverySelectView: View {
    
    @State
    var presenter: VaultRecoverySelectPresenter
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderContentView(
                title: Text(.restoreDecryptVaultTitle),
                subtitle: Text(.restoreDecryptVaultDescription),
                icon: {
                    Image(systemName: "lock.rectangle.stack.fill")
                        .foregroundStyle(.brand500, .brand100)
                }
            )
            .padding(.vertical, Spacing.l)

            SelectDecryptionMethod(
                onFiles: { presenter.onFiles() },
                onCamera: { presenter.onCamera() },
                onEnterManually: { presenter.onEnterManually() }
            )
            .padding(.vertical, Spacing.xll)
            
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .router(router: VaultRecoverySelectRouter(), destination: $presenter.destination)
        .background(Color(Asset.mainBackgroundColor.color))
        .readableContentMargins()
        .fileImporter(
            isPresented: $presenter.showFileImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            onCompletion: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let url): presenter.onFileOpen(url)
                    case .failure(let error): presenter.onFileError(error)
                    }
                }
            })
    }
}

private struct RecoveryKitImage: Transferable {
    enum ImageError: Error {
        case errorDecoding
    }
    let image: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let uiImage = UIImage(data: data) else {
                Log("Error while accessing an image file")
                throw(ImageError.errorDecoding)
            }
            let image = uiImage
            return RecoveryKitImage(image: image)
        }
    }
}

#Preview {
    VaultRecoverySelectView(presenter: .init(
        flowContext: .onboarding(onClose: {}),
        interactor: ModuleInteractorFactory.shared.vaultRecoverySelectModuleInteractor(),
        recoveryData: .cloud(
            .init(
                vaultID: VaultID(),
                name: "Device",
                createdAt: Date(),
                updatedAt: Date(),
                deviceNames: Data(),
                deviceID: DeviceID(),
                schemaVersion: 1,
                seedHash: "scheme",
                reference: "reference",
                kdfSpec: Data(),
                zoneID: .default
            )
        ))
    )
}
