// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public struct PasswordCharacterSet {
    public static let digits = (48...57).map { String(UnicodeScalar($0)!) }
    public static let uppercase = (65...90).map { String(UnicodeScalar($0)!) }
    public static let special = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "-", "_"]
    public static let lowercase = (97...122).map { String(UnicodeScalar($0)!) }
    public static let letters = uppercase + lowercase
}

public protocol PasswordGeneratorInteracting: AnyObject {
    var digits: [String] { get }
    var uppercase: [String] { get }
    var special: [String] { get }
    var lowercase: [String] { get }
    var minPasswordLength: Int { get }
    var prefersPasswordLength: Int { get }
    var maxPasswordLength: Int { get }
    
    func generatePassword(using config: PasswordGenerateConfig) -> String
}

final class PasswordGeneratorInteractor: PasswordGeneratorInteracting {
    
    let digits = PasswordCharacterSet.digits
    let uppercase = PasswordCharacterSet.uppercase
    let special = PasswordCharacterSet.special
    let lowercase = PasswordCharacterSet.lowercase
    let minPasswordLength = 9
    let prefersPasswordLength = 16
    let maxPasswordLength = 64
    
    func generatePassword(using config: PasswordGenerateConfig) -> String {
        let digitsCount: Int = config.hasDigits == false ? 0 : {
            switch config.length {
            case ...8:
                return 2
            case 9...12:
                return secureRandom(in: 2...3)
            case 13...16:
                return secureRandom(in: 3...4)
            case 17...24:
                return secureRandom(in: 3...6)
            default:
                return secureRandom(in: 2...8)
            }
        }()

        let uppercaseCount: Int = config.hasUppercase == false ? 0 : {
            switch config.length {
            case ...8:
                return 1
            case 9...12:
                return secureRandom(in: 1...2)
            case 13...16:
                return secureRandom(in: 2...3)
            case 17...24:
                return secureRandom(in: 2...4)
            default:
                return secureRandom(in: 3...6)
            }
        }()

        let specialCount: Int = config.hasSpecial == false ? 0 : {
            switch config.length {
            case ...8:
                return 1
            case 9...12:
                return secureRandom(in: 1...2)
            case 13...16:
                return secureRandom(in: 2...3)
            case 17...24:
                return secureRandom(in: 2...4)
            default:
                return secureRandom(in: 3...6)
            }
        }()
        
        let minLowercase = max(0, config.length - digitsCount - uppercaseCount - specialCount)
        
        let str = generateRandomCharacters(length: digitsCount, pool: digits) +
        generateRandomCharacters(length: uppercaseCount, pool: uppercase) +
        generateRandomCharacters(length: specialCount, pool: special) +
        generateRandomCharacters(length: minLowercase, pool: lowercase)
        
        return str
            .shuffled()
            .map{ String($0) }
            .joined()
    }
    
    func generateRandomCharacters(length: Int, pool: [String]) -> String {
        (0..<length)
            .compactMap { _ in pool.randomElement() }
            .joined()
    }
}

private extension PasswordGeneratorInteractor {
    
    func secureRandom(in range: ClosedRange<Int>) -> Int {
        precondition(!range.isEmpty, "Range cannot be empty")
        let count = range.upperBound - range.lowerBound + 1
        var randomByte: UInt32 = 0
        let result = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &randomByte)
        if result == errSecSuccess {
            return Int(randomByte % UInt32(count)) + range.lowerBound
        } else {
            fatalError("Unable to generate secure random number")
        }
    }
}
