// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import PDFKit
import Common

public enum RecoveryKitPDFError: Error {
    case loadTemplateFailed
}

public struct RecoveryKitTranslations {
    let title: String
    let author: String
    let creator: String
    let header: String
    let writeDown: String
    
    public init(title: String, author: String, creator: String, header: String, writeDown: String) {
        self.title = title
        self.author = author
        self.creator = creator
        self.header = header
        self.writeDown = writeDown
    }
}

public struct RecoveryKitPDFConfig {
    let wordsSpacing: CGFloat
    let lineHeight: CGFloat
    let logo: UIImage
    let qrCodeLogo: UIImage
    
    public init(
        wordsSpacing: CGFloat,
        lineHeight: CGFloat,
        logo: UIImage,
        qrCodeLogo: UIImage
    ) {
        self.wordsSpacing = wordsSpacing
        self.lineHeight = lineHeight
        self.logo = logo
        self.qrCodeLogo = qrCodeLogo
    }
}

final class RecoveryKitPDFGenerator {
    private let margin = 36.0
    private let scaleQRCodeUp = 7.2
    private let qrCodeCenterImageScale = 8.0
    private let textColor = UIColor(hexString: "#161616")!
    
    private lazy var dateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .medium
        return df
    }()
    
    private let translations: RecoveryKitTranslations
    private let config: RecoveryKitPDFConfig
    
    init(translations: RecoveryKitTranslations, config: RecoveryKitPDFConfig) {
        self.translations = translations
        self.config = config
    }
    
    func generate(
        words: [String],
        entropy: Entropy,
        masterKey: MasterKey?,
        date: Date,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard let templateURL = Bundle.main.url(forResource: "vault-decription-kit-template", withExtension: "pdf"),
              let templatePDF = PDFDocument(url: templateURL),
              let templatePage = templatePDF.page(at: 0) else {
            completion(.failure(RecoveryKitPDFError.loadTemplateFailed))
            return
        }
        
        let pageBounds = templatePage.bounds(for: .mediaBox)
        
        let dateStr = String(localized: .decryptionKitFileDate(dateFormatter.string(from: date)))
        
        let pdfFormat = UIGraphicsPDFRendererFormat()
        pdfFormat.documentInfo = documentInfo(dateStr: dateStr)
        let pageRect = CGRect(x: 0, y: 0, width: pageBounds.width, height: pageBounds.height)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: pdfFormat)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
                        
            drawTemplate(templatePage, in: context, pageSize: pageBounds.size)
            drawDate(dateStr, pageSize: pageBounds.size)
            drawWords(words, pageSize: pageBounds.size)
            
            let qrCodeRect = drawQRCode(entropy: entropy, masterKey: masterKey, pageSize: pageBounds.size)
            drawQRCodeDescription(hasMasterKey: masterKey != nil, qrCodeRect: qrCodeRect, pageSize: pageBounds.size)
        }
        completion(.success(data))
    }
    
    private func documentInfo(dateStr: String) -> [String: Any] {
        [
            kCGPDFContextTitle: "\(translations.title) \(dateStr)",
            kCGPDFContextAuthor: translations.author,
            kCGPDFContextCreator: translations.creator
        ] as [String: Any]
    }
    
    private func drawTemplate(_ templatePage: PDFPage, in context: UIGraphicsPDFRendererContext, pageSize: CGSize) {
        let cgContext = context.cgContext
        cgContext.saveGState()
        cgContext.translateBy(x: 0, y: pageSize.height)
        cgContext.scaleBy(x: 1, y: -1)
        templatePage.draw(with: .mediaBox, to: context.cgContext)
        cgContext.restoreGState()
    }

    private func drawDate(_ dateStr: String, pageSize: CGSize) {
        let dateY = pageSize.height * 0.025
        let dateHeight = 10.0
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: dateHeight, weight: .regular),
            .foregroundColor: textColor
        ]
        let dateAttributedString = NSAttributedString(string: dateStr, attributes: dateAttributes)
        let dateSize = dateAttributedString.size()
        dateAttributedString.draw(at: CGPoint(x: pageSize.width - dateSize.width - margin, y: dateY))
    }
    
    private func drawWords(_ words: [String], pageSize: CGSize) {
        let wordsY = pageSize.height * 0.384

        let wordAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: config.lineHeight, weight: .bold),
            .foregroundColor: textColor
        ]
        let offset = -1.0
        
        for (index, word) in words.enumerated() {
            let y = wordsY + (config.lineHeight + config.wordsSpacing) * Double(index)
            
            let wordAttributed = NSAttributedString(string: word, attributes: wordAttributes)
            let image = makeImage(from: wordAttributed)
            image.draw(at: CGPoint(x: 100, y: y + offset))
        }
    }
    
    private func drawQRCode(entropy: Entropy, masterKey: MasterKey?, pageSize: CGSize) -> CGRect {
        guard let link = RecoveryKitLink.create(from: entropy, masterKey: masterKey) else {
            Log("Can't get Recovery Kit Link while creating QR Code", severity: .error)
            return .zero
        }
        
        if let qrCode = generateQRCode(from: link),
           let qrCodeWithLogo = addLogo(config.qrCodeLogo, to: qrCode) {
            let width = round(pageSize.width * 0.415)
            let height = width
            let x = round(0.51 * pageSize.width)
            let y = round(0.359 * pageSize.height)
            
            let rect = CGRect(x: x, y: y, width: width, height: height)
            qrCodeWithLogo.draw(in: rect)
            return rect
            
        } else {
            return .zero
        }
    }
    
    private func drawQRCodeDescription(hasMasterKey: Bool, qrCodeRect: CGRect, pageSize: CGSize) {
        let margin = qrCodeRect.size.width * 0.1
        let textHeight = 12.0
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: textHeight, weight: .semibold),
            .foregroundColor: textColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let attributedString: NSAttributedString = {
            if hasMasterKey {
                return NSAttributedString(
                    string: String(localized: .decryptionKitFileQrCodeMasterKeyDescription),
                    attributes: attributes
                )
            } else {
                return NSAttributedString(
                    string: String(localized: .decryptionKitFileQrCodeDescription),
                    attributes: attributes
                )
            }
        }()
        
        let size = attributedString.boundingRect(
            with: CGSize(width: qrCodeRect.width - 2 * margin, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        )
        attributedString.draw(in: CGRect(
            x: qrCodeRect.midX - size.width / 2,
            y: qrCodeRect.maxY + 8,
            width: size.width,
            height: size.height)
        )
    }
    
    private func generateQRCode(from text: String) -> CIImage? {
        let data = text.data(using: .ascii)
        
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        let transform = CGAffineTransform(scaleX: scaleQRCodeUp, y: scaleQRCodeUp)
        
        return filter.outputImage?.transformed(by: transform)
    }
    
    private func addLogo(_ logo: UIImage, to qrCode: CIImage) -> UIImage? {
        let logoSize = round(qrCode.extent.size.width / qrCodeCenterImageScale)
        
        let width = qrCode.extent.width
        let height = qrCode.extent.height
        
        guard let logoCGImage = logo.cgImage else {
            return UIImage(ciImage: qrCode)
        }
        
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(CIImage(cgImage: logoCGImage), forKey: kCIInputImageKey)
        
        let scale = logoSize / logo.size.height
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        guard let logoImage = filter.outputImage else {
            return UIImage(ciImage: qrCode)
        }
        
        let logoImageWidth = logoImage.extent.width
        let logoImageHeight = logoImage.extent.height
        
        let transform = CGAffineTransform(
            translationX: round((width - logoImageWidth)/2.0),
            y: round((height - logoImageHeight)/2.0)
        )
        let transformedImage = logoImage.transformed(by: transform)
        
        let logoFilter = CIFilter(name: "CISourceOverCompositing")!
        logoFilter.setValue(transformedImage, forKey: kCIInputImageKey)
        logoFilter.setValue(qrCode, forKey: kCIInputBackgroundImageKey)
        
        guard let ciImage = logoFilter.outputImage else {
            return nil
        }
        
        return UIImage(ciImage: ciImage)
    }
    
    private func makeImage(from attributedString: NSAttributedString) -> UIImage {
        let imageSize = attributedString.size()

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        let image = renderer.image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            let textRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            attributedString.draw(in: textRect)
        }
        
        return image
    }
}
