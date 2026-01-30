// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import UniformTypeIdentifiers

public protocol RecoveryKitScanInteracting: AnyObject {
    func scan(image: UIImage, completion: @escaping VisionScanCompletion)
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)?
    func isPDF(fileURL: URL) -> Bool
    func pdfToImage(url: URL) -> UIImage?
}

public final class RecoveryKitScanInteractor {
    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension RecoveryKitScanInteractor: RecoveryKitScanInteracting {
    public func scan(image: UIImage, completion: @escaping VisionScanCompletion) {
        mainRepository.scan(image: image, completion: completion)
    }

    public func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)? {
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

    public func isPDF(fileURL: URL) -> Bool {
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
                "RecoveryKitScanInteractor - Error while trying to identify a file: \(error)",
                module: .moduleInteractor,
                severity: .error
            )
        }

        return false
    }

    public func pdfToImage(url: URL) -> UIImage? {
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
}
