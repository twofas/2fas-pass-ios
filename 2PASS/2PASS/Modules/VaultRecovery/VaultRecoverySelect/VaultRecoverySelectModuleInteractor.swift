// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common
import UniformTypeIdentifiers

protocol VaultRecoverySelectModuleInteracting: AnyObject {
    func openFile(url: URL, completion: @escaping (Result<Data, ImportOpenFileError>) -> Void)
    func scan(image: UIImage, completion: @escaping VisionScanCompletion)
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)?
    func isPDF(fileURL: URL) -> Bool
    func pdfToImage(url: URL) -> UIImage?
    func validateEntropy(_ entropy: Entropy, for data: VaultRecoveryData) -> Bool
}

final class VaultRecoverySelectModuleInteractor {
    private let importInteractor: ImportInteracting
    
    init(
        importInteractor: ImportInteracting
    ) {
        self.importInteractor = importInteractor
    }
}

extension VaultRecoverySelectModuleInteractor: VaultRecoverySelectModuleInteracting {
    func openFile(url: URL, completion: @escaping (Result<Data, ImportOpenFileError>) -> Void) {
        importInteractor.openFile(url: url, completion: completion)
    }
    
    func scan(image: UIImage, completion: @escaping VisionScanCompletion) {
        importInteractor.scan(image: image, completion: completion)
    }
    
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)? {
        guard let result = RecoveryKitLink.parse(from: str) else {
            return nil
        }
        let entropy = Data(base64Encoded: result.entropy)
        let masterKey = {
            if let masterKey = result.masterKey {
                return Data(base64Encoded: masterKey)
            }
            return nil
        }()
        guard let entropy else {
            return nil
        }
        return (entropy: entropy, masterKey: masterKey)
    }
    
    func isPDF(fileURL: URL) -> Bool {
        do {
            let resourceValues: URLResourceValues
            if fileURL.startAccessingSecurityScopedResource() {
                resourceValues = try fileURL.resourceValues(forKeys: [.typeIdentifierKey])
                fileURL.stopAccessingSecurityScopedResource()
            } else {
                resourceValues = try fileURL.resourceValues(forKeys: [.typeIdentifierKey])
            }
            if let typeIdentifier = resourceValues.typeIdentifier,
               let type = UTType(typeIdentifier) {
                return type.conforms(to: .pdf)
            }
        } catch {
            fileURL.stopAccessingSecurityScopedResource()
            Log(
                "VaultRecoverySelectModuleInteractor - Error while trying to identify a file: \(error)",
                module: .moduleInteractor,
                severity: .error
            )
        }
        
        return false
    }
    
    func pdfToImage(url: URL) -> UIImage? {
        let document: CGPDFDocument?
        if url.startAccessingSecurityScopedResource() {
            document = CGPDFDocument(url as CFURL)
            url.stopAccessingSecurityScopedResource()
        } else {
            document = CGPDFDocument(url as CFURL)
        }
        guard let document,
              let page = document.page(at: 1) else {
            return nil
        }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let img = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.drawPDFPage(page)
        }
        return img
    }
    
    func validateEntropy(_ entropy: Entropy, for data: VaultRecoveryData) -> Bool {
        let vaultSeedHash: String? = {
            switch data {
            case .file(let vault):
                vault.encryption?.seedHash
            case .cloud(let vaultData):
                vaultData.seedHash
            }
        }()
        
        let vaultID: UUID? = {
            switch data {
            case .file(let vault):
                UUID(uuidString: vault.vault.id)
            case .cloud(let vaultData):
                vaultData.vaultID
            }
        }()
        
        guard let vaultSeedHash, let vaultID else {
            return false
        }
        guard let seedHash = importInteractor.generateSeedHash(from: entropy, vaultID: vaultID) else {
            return false
        }
        
        let seedHashBase64 = Data(hexString: seedHash)?.base64EncodedString()
        return seedHashBase64 == vaultSeedHash
    }
}
