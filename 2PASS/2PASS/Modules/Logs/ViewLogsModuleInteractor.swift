// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol ViewLogsModuleInteracting: AnyObject {
    func listAll() -> [LogEntry]
    func generateFile() async throws -> URL
}

final class ViewLogsModuleInteractor {
    private let debugInteractor: DebugInteracting
    
    init(debugInteractor: DebugInteracting) {
        self.debugInteractor = debugInteractor
    }
}

extension ViewLogsModuleInteractor: ViewLogsModuleInteracting {
    
    func listAll() -> [LogEntry] {
        debugInteractor.listAllLogEntries()
    }
    
    enum GenerateLogFileError: Error {
        case badData
        case writeFailed(Error)
    }
    
    func generateFile() async throws(GenerateLogFileError) -> URL {
        let logs = debugInteractor.generateLogs()
        
        guard let logsData = logs.data(using: .utf8) else {
            throw .badData
        }
        
        return try writeToFile(logsData)
    }
    
    private func writeToFile(_ data: Data) throws(GenerateLogFileError) -> URL {
        do {
            let fileName = "2FAS_Pass_Logs_\(Date().fileDateAndTime()).txt"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: url)
            return url
        } catch {
            throw .writeFailed(error)
        }
    }
}
