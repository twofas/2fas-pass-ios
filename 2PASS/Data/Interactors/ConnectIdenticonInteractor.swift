// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CryptoKit

public protocol ConnectIdenticonInteracting: AnyObject {
    func identiconSVG(fromPublicKey pkPersBeHex: String, colorScheme: ColorScheme) -> String?
}

final class ConnectIdenticonInteractor: ConnectIdenticonInteracting {
 
    func identiconSVG(fromPublicKey pkPersBeHex: String, colorScheme: ColorScheme) -> String? {
        guard let pkPersBeData = Data(hexString: pkPersBeHex) else {
            return nil
        }
        let hash = SHA256.hash(data: pkPersBeData).toHEXString()
        
        guard let iconIndex = Int(hash[0..<2], radix: 16),
              let identiconColor1Value = Int(hash[2..<4], radix: 16),
              let identiconColor2Value = Int(hash[4..<6], radix: 16),
              let identiconColor3Value = Int(hash[6..<8], radix: 16) else {
            return nil
        }
        
        let icon = ConnectIdenticonInteractor.identiconSVGs[iconIndex % ConnectIdenticonInteractor.identiconSVGs.count]
        
        var identiconColors = ConnectIdenticonInteractor.identiconColors
        let identiconColor1 = color(forValue: identiconColor1Value, in: &identiconColors)
        let identiconColor2 = color(forValue: identiconColor2Value, in: &identiconColors)
        let identiconColor3 = color(forValue: identiconColor3Value, in: &identiconColors)
        
        return icon
            .replacingOccurrences(of: "SEC_COLOR_1", with: identiconColor1.hexColor(for: colorScheme))
            .replacingOccurrences(of: "SEC_COLOR_2", with: identiconColor2.hexColor(for: colorScheme))
            .replacingOccurrences(of: "SEC_COLOR_3", with: identiconColor3.hexColor(for: colorScheme))
    }
    
    private func color(forValue hash: Int, in colors: inout [IdenticonColor]) -> IdenticonColor {
        let index = hash % colors.count
        let color = colors[index]
        colors.remove(at: index)
        return color
    }
}
