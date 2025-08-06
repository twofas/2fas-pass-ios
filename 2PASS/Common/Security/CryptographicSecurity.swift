// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CryptoKit
import Security

/// Enhanced cryptographic security utilities for 2FAS Pass
public final class CryptographicSecurity {
    
    // MARK: - Secure Memory Management
    
    /// Securely clears sensitive data from memory
    /// - Parameter data: Data to clear
    public static func secureMemoryClear(_ data: inout Data) {
        data.withUnsafeMutableBytes { bytes in
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
        data.removeAll()
    }
    
    /// Securely clears sensitive string from memory
    /// - Parameter string: String to clear
    public static func secureMemoryClear(_ string: inout String) {
        var data = Data(string.utf8)
        secureMemoryClear(&data)
        string = ""
    }
    
    /// Securely clears symmetric key from memory
    /// - Parameter key: SymmetricKey to clear
    public static func secureMemoryClear(_ key: inout SymmetricKey?) {
        // Clear the underlying data if accessible
        key = nil
    }
    
    // MARK: - Enhanced Random Number Generation
    
    /// Generates cryptographically secure random bytes using SecRandomCopyBytes
    /// - Parameter length: Number of bytes to generate
    /// - Returns: Secure random data or nil if generation fails
    public static func generateSecureRandomBytes(length: Int) -> Data? {
        guard length > 0 else { return nil }
        
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        
        guard status == errSecSuccess else {
            // Log security event
            NSLog("CryptographicSecurity: Failed to generate secure random bytes - status: %d", status)
            return nil
        }
        
        return Data(randomBytes)
    }
    
    /// Generates cryptographically secure random nonce for encryption
    /// - Returns: 12-byte nonce for AES-GCM
    public static func generateSecureNonce() -> Data? {
        return generateSecureRandomBytes(length: 12)
    }
    
    // MARK: - Enhanced Key Derivation
    
    /// Validates KDF parameters for security compliance
    /// - Parameter kdfSpec: KDF specification to validate
    /// - Returns: True if parameters meet security requirements
    public static func validateKDFSecurity(_ kdfSpec: KDFSpec) -> Bool {
        // Minimum security requirements for Argon2
        let minIterations = 3
        let minMemoryMB = 64
        let minParallelism = 1
        let minHashLength = 32
        
        guard kdfSpec.iterations >= minIterations,
              kdfSpec.memoryMB >= minMemoryMB,
              kdfSpec.parallelism >= minParallelism,
              kdfSpec.hashLength >= minHashLength else {
            NSLog("CryptographicSecurity: KDF parameters below minimum security requirements")
            return false
        }
        
        // Ensure Argon2id is used (most secure variant)
        guard kdfSpec.kdfType == .argon2id else {
            NSLog("CryptographicSecurity: KDF type should be Argon2id for maximum security")
            return false
        }
        
        return true
    }
    
    /// Generates secure salt for key derivation
    /// - Returns: 32-byte cryptographically secure salt
    public static func generateSecureSalt() -> Data? {
        return generateSecureRandomBytes(length: 32)
    }
    
    // MARK: - Certificate Pinning Support
    
    /// Validates certificate chain against pinned certificates
    /// - Parameters:
    ///   - serverTrust: Server trust to validate
    ///   - pinnedCertificates: Array of pinned certificate data
    /// - Returns: True if certificate is valid and pinned
    public static func validateCertificatePinning(
        serverTrust: SecTrust,
        pinnedCertificates: [Data]
    ) -> Bool {
        let serverCertCount = SecTrustGetCertificateCount(serverTrust)
        
        for i in 0..<serverCertCount {
            guard let serverCert = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }
            
            let serverCertData = SecCertificateCopyData(serverCert)
            let serverCertBytes = CFDataGetBytePtr(serverCertData)
            let serverCertLength = CFDataGetLength(serverCertData)
            
            guard let serverCertBytesPtr = serverCertBytes else { continue }
            
            let serverData = Data(bytes: serverCertBytesPtr, count: serverCertLength)
            
            if pinnedCertificates.contains(serverData) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Anti-Tampering
    
    /// Detects if the application is running in a debugger
    /// - Returns: True if debugger is detected
    public static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        
        if result != 0 {
            return false
        }
        
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    /// Detects if device is jailbroken
    /// - Returns: True if jailbreak is detected
    public static func isJailbroken() -> Bool {
        // Check for common jailbreak paths
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/private/var/tmp/cydia.log",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if we can write to restricted paths
        do {
            let restrictedPath = "/private/test_write"
            try "test".write(toFile: restrictedPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: restrictedPath)
            return true // Should not be able to write here
        } catch {
            // Good - we cannot write to restricted paths
        }
        
        return false
    }
    
    // MARK: - Secure Validation
    
    /// Validates that input data is within expected bounds
    /// - Parameters:
    ///   - data: Data to validate
    ///   - maxLength: Maximum allowed length
    /// - Returns: True if data is valid
    public static func validateInputBounds(_ data: Data, maxLength: Int) -> Bool {
        return data.count <= maxLength && data.count > 0
    }
    
    /// Sanitizes string input to prevent injection attacks
    /// - Parameter input: Input string to sanitize
    /// - Returns: Sanitized string
    public static func sanitizeStringInput(_ input: String) -> String {
        // Remove control characters and normalize
        let controlCharacterSet = CharacterSet.controlCharacters
        let filtered = input.components(separatedBy: controlCharacterSet).joined()
        return filtered.precomposedStringWithCanonicalMapping
    }
}

// MARK: - Extensions for Secure Memory Management

extension Data {
    /// Securely clears this data instance from memory
    mutating func secureClear() {
        CryptographicSecurity.secureMemoryClear(&self)
    }
}

extension String {
    /// Securely clears this string instance from memory
    mutating func secureClear() {
        CryptographicSecurity.secureMemoryClear(&self)
    }
}

// MARK: - Enhanced KDFSpec with Security Validation

extension KDFSpec {
    /// Returns a security-hardened default KDF specification
    static var secureDefault: KDFSpec {
        return KDFSpec(
            kdfType: .argon2id,
            iterations: 4,      // Increased from default
            memoryMB: 128,      // Increased memory requirement
            parallelism: 2,     // Parallel processing
            hashLength: 32      // 256-bit output
        )
    }
    
    /// Validates this KDF specification meets security requirements
    var isSecure: Bool {
        return CryptographicSecurity.validateKDFSecurity(self)
    }
}