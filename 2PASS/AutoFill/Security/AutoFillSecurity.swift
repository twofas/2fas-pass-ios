// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import AuthenticationServices
import Common

/// Security enhancements for AutoFill extension
public final class AutoFillSecurity {
    
    // MARK: - Security Constants
    
    private static let maxCredentialRequestsPerSession = 10
    private static let credentialAccessTimeout: TimeInterval = 300 // 5 minutes
    private static let suspiciousRequestThreshold = 5
    
    private static var requestCount = 0
    private static var sessionStartTime = Date()
    private static var suspiciousRequests: [String] = []
    
    // MARK: - Request Validation
    
    /// Validates AutoFill credential request for security compliance
    /// - Parameter request: The credential request to validate
    /// - Returns: Validation result
    public static func validateCredentialRequest(_ request: ASCredentialRequest) -> AutoFillValidationResult {
        // Reset session if expired
        if Date().timeIntervalSince(sessionStartTime) > credentialAccessTimeout {
            resetSession()
        }
        
        // Check request rate limiting
        requestCount += 1
        if requestCount > maxCredentialRequestsPerSession {
            NSLog("AutoFillSecurity: Request rate limit exceeded")
            return .rateLimited
        }
        
        // Validate service identifier
        guard let serviceIdentifier = extractServiceIdentifier(from: request) else {
            NSLog("AutoFillSecurity: Invalid service identifier")
            return .invalidRequest
        }
        
        // Check for suspicious patterns
        if isSuspiciousServiceIdentifier(serviceIdentifier) {
            suspiciousRequests.append(serviceIdentifier)
            if suspiciousRequests.count >= suspiciousRequestThreshold {
                NSLog("AutoFillSecurity: Too many suspicious requests")
                return .suspiciousActivity
            }
            return .suspicious
        }
        
        // Validate domain
        if !isValidDomain(serviceIdentifier) {
            NSLog("AutoFillSecurity: Invalid domain format")
            return .invalidDomain
        }
        
        return .valid
    }
    
    /// Validates service identifiers for credential list preparation
    /// - Parameter serviceIdentifiers: Service identifiers to validate
    /// - Returns: Validation result
    public static func validateServiceIdentifiers(_ serviceIdentifiers: [ASCredentialServiceIdentifier]) -> AutoFillValidationResult {
        guard !serviceIdentifiers.isEmpty else {
            return .invalidRequest
        }
        
        for identifier in serviceIdentifiers {
            let domain = identifier.identifier
            
            if !isValidDomain(domain) {
                NSLog("AutoFillSecurity: Invalid service identifier domain: %@", domain)
                return .invalidDomain
            }
            
            if isSuspiciousServiceIdentifier(domain) {
                return .suspicious
            }
        }
        
        return .valid
    }
    
    // MARK: - Credential Security
    
    /// Securely creates password credential with validation
    /// - Parameters:
    ///   - user: Username
    ///   - password: Password
    ///   - request: Original credential request
    /// - Returns: Secure password credential or nil if validation fails
    public static func createSecureCredential(
        user: String,
        password: String,
        for request: ASCredentialRequest
    ) -> ASPasswordCredential? {
        // Validate inputs
        guard !user.isEmpty || !password.isEmpty else {
            NSLog("AutoFillSecurity: Empty credentials provided")
            return nil
        }
        
        // Sanitize username
        let sanitizedUser = CryptographicSecurity.sanitizeStringInput(user)
        
        // Validate password strength (basic check for AutoFill)
        if password.count < 4 {
            NSLog("AutoFillSecurity: Warning - Very short password detected")
        }
        
        // Create credential with security context
        let credential = ASPasswordCredential(user: sanitizedUser, password: password)
        
        // Log credential access (without sensitive data)
        logCredentialAccess(for: extractServiceIdentifier(from: request) ?? "unknown")
        
        return credential
    }
    
    // MARK: - Session Management
    
    /// Resets the AutoFill security session
    public static func resetSession() {
        requestCount = 0
        sessionStartTime = Date()
        suspiciousRequests.removeAll()
        NSLog("AutoFillSecurity: Session reset")
    }
    
    /// Checks if current session is valid
    /// - Returns: True if session is valid
    public static func isSessionValid() -> Bool {
        let sessionAge = Date().timeIntervalSince(sessionStartTime)
        return sessionAge <= credentialAccessTimeout && requestCount <= maxCredentialRequestsPerSession
    }
    
    // MARK: - Private Validation Methods
    
    private static func extractServiceIdentifier(from request: ASCredentialRequest) -> String? {
        if let passwordRequest = request as? ASPasswordCredentialRequest {
            return passwordRequest.credentialIdentity.serviceIdentifier.identifier
        }
        return request.credentialIdentity.serviceIdentifier.identifier
    }
    
    private static func isValidDomain(_ domain: String) -> Bool {
        // Basic domain validation
        let domainRegex = try! NSRegularExpression(
            pattern: "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z]{2,}$"
        )
        
        let range = NSRange(location: 0, length: domain.count)
        return domainRegex.firstMatch(in: domain, options: [], range: range) != nil ||
               domain == "localhost" || // Allow localhost for development
               domain.hasPrefix("192.168.") || // Allow local network
               domain.hasPrefix("10.") || // Allow local network
               domain.hasPrefix("172.") // Allow local network
    }
    
    private static func isSuspiciousServiceIdentifier(_ identifier: String) -> Bool {
        let suspiciousPatterns = [
            "phishing",
            "fake",
            "test-site",
            "malicious",
            "suspicious",
            "evil",
            "hack",
            "exploit",
            // Add more patterns based on threat intelligence
        ]
        
        let lowercasedIdentifier = identifier.lowercased()
        
        for pattern in suspiciousPatterns {
            if lowercasedIdentifier.contains(pattern) {
                return true
            }
        }
        
        // Check for suspicious TLDs
        let suspiciousTLDs = [".tk", ".ml", ".ga", ".cf"]
        for tld in suspiciousTLDs {
            if lowercasedIdentifier.hasSuffix(tld) {
                return true
            }
        }
        
        return false
    }
    
    private static func logCredentialAccess(for serviceIdentifier: String) {
        // Log credential access for security monitoring
        // Don't log sensitive credential data, only metadata
        NSLog("AutoFillSecurity: Credential accessed for service: %@", serviceIdentifier)
        
        // In production, you might want to send this to a security monitoring service
        NotificationCenter.default.post(
            name: .autoFillCredentialAccessed,
            object: ["serviceIdentifier": serviceIdentifier, "timestamp": Date()]
        )
    }
}

// MARK: - Data Protection

extension AutoFillSecurity {
    
    /// Securely handles credential data in memory
    /// - Parameter credential: Credential to secure
    /// - Returns: Secured credential wrapper
    public static func secureCredentialInMemory(_ credential: ASPasswordCredential) -> SecuredCredential {
        return SecuredCredential(credential: credential)
    }
    
    /// Clears sensitive credential data from memory
    /// - Parameter credential: Credential to clear
    public static func clearCredentialFromMemory(_ credential: inout ASPasswordCredential?) {
        credential = nil
        // Force garbage collection of the credential object
        // Note: Swift/ARC will handle this automatically, but we explicitly nil it
    }
}

// MARK: - Types

public enum AutoFillValidationResult {
    case valid
    case invalid
    case invalidRequest
    case invalidDomain
    case rateLimited
    case suspicious
    case suspiciousActivity
    case sessionExpired
}

/// Secured credential wrapper that automatically clears sensitive data
public class SecuredCredential {
    private var _credential: ASPasswordCredential?
    private let creationTime = Date()
    private let maxLifetime: TimeInterval = 60 // 1 minute max lifetime
    
    init(credential: ASPasswordCredential) {
        self._credential = credential
        
        // Auto-clear after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + maxLifetime) { [weak self] in
            self?.clear()
        }
    }
    
    public var credential: ASPasswordCredential? {
        guard let cred = _credential,
              Date().timeIntervalSince(creationTime) <= maxLifetime else {
            clear()
            return nil
        }
        return cred
    }
    
    public func clear() {
        _credential = nil
    }
    
    deinit {
        clear()
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let autoFillCredentialAccessed = Notification.Name("AutoFillCredentialAccessed")
    static let autoFillSecurityViolation = Notification.Name("AutoFillSecurityViolation")
}