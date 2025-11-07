// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol RecoveryKitInteracting: AnyObject {
    func generateRecoveryKitPDF(
        entropy: Entropy,
        words: [String],
        masterKey: MasterKey?,
        completion: @escaping (URL?) -> Void
    )
    func clear()
}

final class RecoveryKitInteractor {
    private var fileURL: URL?
    
    private let generator: RecoveryKitPDFGenerator
    private let mainRepository: MainRepository
    
    init(translations: RecoveryKitTranslations, pdfConfig: RecoveryKitPDFConfig, mainRepository: MainRepository) {
        self.generator = RecoveryKitPDFGenerator(translations: translations, config: pdfConfig)
        self.mainRepository = mainRepository
    }
}

extension RecoveryKitInteractor: RecoveryKitInteracting {
    func generateRecoveryKitPDF(
        entropy: Entropy,
        words: [String],
        masterKey: MasterKey?,
        completion: @escaping (URL?) -> Void
    ) {
        Log("RecoveryKitInteractor: Generating Recovery Kit PDF", module: .interactor)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.generator
                .generate(
                    words: words,
                    entropy: entropy,
                    masterKey: masterKey,
                    date: self.mainRepository.currentDate
                ) { [weak self] result in
                    let tempDir = FileManager.default.temporaryDirectory
                    let currentDate = self?.mainRepository.currentDate ?? Date()
                    let fileName = "2FAS_Pass_DecryptionKit_\(currentDate.fileDateAndTime()).pdf"
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    self?.fileURL = fileURL
                    do {
                        let data = try result.get()
                        try data.write(to: fileURL)
                        DispatchQueue.main.async {
                            completion(fileURL)
                        }
                    } catch {
                        Log(
                            "RecoveryKitInteractor: Can't write generated Recovery Kit to \(fileURL), error: \(error)",
                            module: .interactor
                        )
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                }
        }
    }
    
    func clear() {
        if let fileURL {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                Log(
                    "RecoveryKitInteractor: Can't delete Recovery kit at path: \(fileURL), error: \(error)",
                    module: .interactor
                )
            }
            self.fileURL = nil
        }
    }
}
