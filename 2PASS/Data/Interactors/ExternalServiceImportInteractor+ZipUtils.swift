// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import ZIPFoundation

extension ExternalServiceImportInteractor.ImportContext {

    /// Extracts a ZIP entry into an in-memory `Data` buffer, defending against:
    /// - **Zip slip**: entries whose path escapes the archive root (`..`, absolute paths).
    /// - **Zip bomb**: tiny compressed files that decompress to exhaust memory.
    ///
    /// Vendor importers never write extracted bytes to disk — the iOS sandbox already
    /// contains filesystem escapes — so the primary risk is memory-exhaustion DoS.
    /// `maxBytes` should mirror the input file-size ceiling for the service.
    func extract(
        _ entry: Entry,
        from archive: Archive,
        maxBytes: Int = Config.maximumExternalImportFileSize
    ) throws(ExternalServiceImportError) -> Data {
        try validateArchivePath(entry.path)
        var buffer = Data()
        buffer.reserveCapacity(min(Int(clamping: entry.uncompressedSize), maxBytes))
        do {
            _ = try archive.extract(entry) { chunk in
                guard buffer.count + chunk.count <= maxBytes else {
                    throw ExternalServiceImportError.wrongFileSize
                }
                buffer.append(chunk)
            }
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }
        return buffer
    }

    private func validateArchivePath(_ path: String) throws(ExternalServiceImportError) {
        guard !path.isEmpty, !path.hasPrefix("/") else {
            throw .wrongFormat
        }
        for component in path.split(separator: "/", omittingEmptySubsequences: false) {
            if component == ".." {
                throw .wrongFormat
            }
        }
    }
}
