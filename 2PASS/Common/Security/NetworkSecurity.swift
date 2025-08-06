// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Network
import Security

/// Enhanced network security manager for 2FAS Pass
public final class NetworkSecurity: NSObject {
    
    // MARK: - Certificate Pinning
    
    private static let pinnedCertificates: [String: [Data]] = {
        var certificates: [String: [Data]] = [:]
        
        // Load pinned certificates from bundle
        guard let path = Bundle.main.path(forResource: "PinnedCertificates", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            NSLog("NetworkSecurity: Warning - No pinned certificates found")
            return [:]
        }
        
        for (domain, certNames) in plist {
            guard let domain = domain as? String,
                  let certNames = certNames as? [String] else {
                continue
            }
            
            var domainCerts: [Data] = []
            for certName in certNames {
                if let certPath = Bundle.main.path(forResource: certName, ofType: "cer"),
                   let certData = Data(base64Encoded: try! String(contentsOfFile: certPath)) {
                    domainCerts.append(certData)
                }
            }
            
            if !domainCerts.isEmpty {
                certificates[domain] = domainCerts
            }
        }
        
        return certificates
    }()
    
    /// Validates server certificate against pinned certificates
    /// - Parameters:
    ///   - challenge: Authentication challenge
    ///   - completionHandler: Completion handler for the challenge
    public func handleCertificateChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        
        // Check if we have pinned certificates for this host
        guard let pinnedCerts = Self.pinnedCertificates[host] else {
            // No pinned certificates, use default validation
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Validate certificate pinning
        if CryptographicSecurity.validateCertificatePinning(
            serverTrust: serverTrust,
            pinnedCertificates: pinnedCerts
        ) {
            // Certificate is pinned and valid
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Certificate pinning failed
            NSLog("NetworkSecurity: Certificate pinning validation failed for host: %@", host)
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    // MARK: - Network Monitoring
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkSecurityMonitor")
    
    /// Starts monitoring network conditions for security threats
    public func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.handleNetworkPathUpdate(path)
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    /// Stops network monitoring
    public func stopNetworkMonitoring() {
        networkMonitor.cancel()
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        // Monitor for suspicious network conditions
        if path.status == .satisfied {
            // Check if we're on a potentially unsafe network
            if path.usesInterfaceType(.wifi) {
                // Could implement additional WiFi security checks here
                checkWiFiSecurity()
            }
        }
    }
    
    private func checkWiFiSecurity() {
        // Placeholder for WiFi security checks
        // Could check for known unsafe networks, captive portals, etc.
    }
    
    // MARK: - Request Security
    
    /// Validates outgoing network request for security compliance
    /// - Parameter request: URL request to validate
    /// - Returns: True if request meets security requirements
    public func validateOutgoingRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }
        
        // Ensure HTTPS is used
        guard url.scheme == "https" else {
            NSLog("NetworkSecurity: Blocking non-HTTPS request to: %@", url.absoluteString)
            return false
        }
        
        // Check for sensitive data in URL parameters
        if let query = url.query, containsSensitiveData(query) {
            NSLog("NetworkSecurity: Blocking request with sensitive data in URL")
            return false
        }
        
        // Validate headers
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if containsSensitiveData("\(key)=\(value)") {
                    NSLog("NetworkSecurity: Blocking request with sensitive data in headers")
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Sanitizes response data before processing
    /// - Parameter data: Response data
    /// - Returns: Sanitized data
    public func sanitizeResponseData(_ data: Data) -> Data {
        // Validate data size to prevent memory exhaustion attacks
        let maxResponseSize = 50 * 1024 * 1024 // 50MB
        if data.count > maxResponseSize {
            NSLog("NetworkSecurity: Response data exceeds maximum size limit")
            return Data() // Return empty data for oversized responses
        }
        
        return data
    }
    
    private func containsSensitiveData(_ string: String) -> Bool {
        let sensitivePatterns = [
            "password=",
            "token=",
            "key=",
            "secret=",
            "auth=",
            "session="
        ]
        
        let lowercased = string.lowercased()
        return sensitivePatterns.contains { lowercased.contains($0) }
    }
}

// MARK: - URLSessionDelegate Extension

extension NetworkSecurity: URLSessionDelegate {
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleCertificateChallenge(challenge, completionHandler: completionHandler)
    }
}

// MARK: - Secure URL Session Factory

extension NetworkSecurity {
    /// Creates a secure URL session with proper configuration
    /// - Returns: Configured URL session with security settings
    public static func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        
        // Security configurations
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        
        // Disable caching for sensitive requests
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Additional security headers
        configuration.httpAdditionalHeaders = [
            "User-Agent": "2FAS-Pass-iOS/1.0",
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY"
        ]
        
        let networkSecurity = NetworkSecurity()
        return URLSession(configuration: configuration, delegate: networkSecurity, delegateQueue: nil)
    }
}