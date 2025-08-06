// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import UIKit
import sys.sysctl

/// Runtime protection against debugging, jailbreaking, and tampering
public final class RuntimeProtection {
    
    private static var isMonitoring = false
    private static let monitoringQueue = DispatchQueue(label: "RuntimeProtectionMonitor", qos: .utility)
    
    // MARK: - Public API
    
    /// Starts runtime protection monitoring
    public static func startProtection() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        NSLog("RuntimeProtection: Starting runtime security monitoring")
        
        // Perform initial security checks
        performSecurityAudit()
        
        // Start continuous monitoring
        startContinuousMonitoring()
    }
    
    /// Stops runtime protection monitoring
    public static func stopProtection() {
        isMonitoring = false
        NSLog("RuntimeProtection: Stopping runtime security monitoring")
    }
    
    /// Performs comprehensive security audit
    /// - Returns: True if all security checks pass
    public static func performSecurityAudit() -> Bool {
        NSLog("RuntimeProtection: Performing comprehensive security audit")
        
        var securityIssues: [String] = []
        
        // Check for jailbreak
        if CryptographicSecurity.isJailbroken() {
            securityIssues.append("Device is jailbroken")
        }
        
        // Check for debugger
        if CryptographicSecurity.isDebuggerAttached() {
            securityIssues.append("Debugger detected")
        }
        
        // Check for injection
        if isInjectionDetected() {
            securityIssues.append("Code injection detected")
        }
        
        // Check for tampering
        if isTamperingDetected() {
            securityIssues.append("Application tampering detected")
        }
        
        // Check for simulator
        if isRunningOnSimulator() {
            securityIssues.append("Running on simulator")
        }
        
        // Check for suspicious processes
        if areSuspiciousProcessesRunning() {
            securityIssues.append("Suspicious processes detected")
        }
        
        if !securityIssues.isEmpty {
            NSLog("RuntimeProtection: Security issues detected: %@", securityIssues.joined(separator: ", "))
            handleSecurityViolation(.multipleThreats(securityIssues))
            return false
        }
        
        NSLog("RuntimeProtection: Security audit passed")
        return true
    }
    
    // MARK: - Anti-Debugging
    
    /// Enhanced debugger detection using multiple techniques
    /// - Returns: True if debugger is detected
    private static func isDebuggerAttached() -> Bool {
        // Method 1: ptrace check
        if CryptographicSecurity.isDebuggerAttached() {
            return true
        }
        
        // Method 2: sysctl check
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        if result == 0 && (info.kp_proc.p_flag & P_TRACED) != 0 {
            return true
        }
        
        // Method 3: Check for common debugger ports
        if isListeningOnDebuggerPorts() {
            return true
        }
        
        return false
    }
    
    private static func isListeningOnDebuggerPorts() -> Bool {
        let suspiciousPorts: [UInt16] = [8080, 9000, 27042, 22] // Common debugger/SSH ports
        
        for port in suspiciousPorts {
            if isPortOpen(port) {
                return true
            }
        }
        
        return false
    }
    
    private static func isPortOpen(_ port: UInt16) -> Bool {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket != -1 else { return false }
        
        defer { close(socket) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    // MARK: - Jailbreak Detection
    
    /// Enhanced jailbreak detection using multiple techniques
    /// - Returns: True if device is jailbroken
    private static func isJailbroken() -> Bool {
        return CryptographicSecurity.isJailbroken() || 
               checkAdditionalJailbreakIndicators()
    }
    
    private static func checkAdditionalJailbreakIndicators() -> Bool {
        // Check for fork capability (jailbroken devices can fork)
        let forkResult = fork()
        if forkResult >= 0 {
            if forkResult > 0 {
                // Parent process - wait for child
                waitpid(forkResult, nil, 0)
            } else {
                // Child process - exit immediately
                exit(0)
            }
            return true // Fork succeeded, likely jailbroken
        }
        
        // Check system directories permissions
        if canWriteToSystemDirectories() {
            return true
        }
        
        return false
    }
    
    private static func canWriteToSystemDirectories() -> Bool {
        let testPaths = [
            "/private/var/mobile/Library/Preferences/com.apple.springboard.plist",
            "/System/Library/CoreServices/SpringBoard.app",
            "/private/var/lib/dpkg/info"
        ]
        
        for path in testPaths {
            if FileManager.default.isWritableFile(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Code Injection Detection
    
    /// Detects code injection attempts
    /// - Returns: True if injection is detected
    private static func isInjectionDetected() -> Bool {
        // Check for suspicious dylibs
        if hasSuspiciousDynamicLibraries() {
            return true
        }
        
        // Check for hook frameworks
        if hasHookingFrameworks() {
            return true
        }
        
        return false
    }
    
    private static func hasSuspiciousDynamicLibraries() -> Bool {
        let suspiciousLibs = [
            "FridaGadget",
            "frida",
            "cynject",
            "libcycript",
            "substrate",
            "Tweak",
            "Hooks"
        ]
        
        var imageCount: UInt32 = 0
        let images = _dyld_image_count()
        
        for i in 0..<images {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                
                for suspiciousLib in suspiciousLibs {
                    if name.lowercased().contains(suspiciousLib.lowercased()) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private static func hasHookingFrameworks() -> Bool {
        // Check for common hooking frameworks
        let hookingFrameworks = [
            "MSHookFunction",
            "MSHookMessageEx",
            "CydiaSubstrate"
        ]
        
        for framework in hookingFrameworks {
            if dlsym(dlopen(nil, RTLD_NOW), framework) != nil {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Tampering Detection
    
    /// Detects application tampering
    /// - Returns: True if tampering is detected
    private static func isTamperingDetected() -> Bool {
        // Check code signature
        if !isCodeSignatureValid() {
            return true
        }
        
        // Check bundle integrity
        if !isBundleIntegrityValid() {
            return true
        }
        
        return false
    }
    
    private static func isCodeSignatureValid() -> Bool {
        // Basic code signature validation
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/usr/bin/codesign"
        task.arguments = ["-v", bundlePath]
        
        let pipe = Pipe()
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()
        
        return task.terminationStatus == 0
    }
    
    private static func isBundleIntegrityValid() -> Bool {
        // Check if Info.plist exists and has expected structure
        guard let infoPlist = Bundle.main.infoDictionary,
              let bundleId = infoPlist["CFBundleIdentifier"] as? String,
              bundleId.contains("2fas") else {
            return false
        }
        
        // Additional bundle checks can be added here
        return true
    }
    
    // MARK: - Simulator Detection
    
    /// Detects if running on simulator
    /// - Returns: True if running on simulator
    private static func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Suspicious Process Detection
    
    /// Detects suspicious processes
    /// - Returns: True if suspicious processes are running
    private static func areSuspiciousProcessesRunning() -> Bool {
        // This is a placeholder - would need more sophisticated process enumeration
        // Check for known analysis tools
        let suspiciousProcesses = [
            "cycript",
            "frida-server",
            "gdb",
            "lldb"
        ]
        
        // In a real implementation, you would enumerate running processes
        // and check against the suspicious list
        
        return false
    }
    
    // MARK: - Continuous Monitoring
    
    private static func startContinuousMonitoring() {
        monitoringQueue.asyncAfter(deadline: .now() + 30) {
            guard isMonitoring else { return }
            
            if !performSecurityAudit() {
                handleSecurityViolation(.runtimeThreatDetected)
            }
            
            // Schedule next check
            startContinuousMonitoring()
        }
    }
    
    // MARK: - Security Violation Handling
    
    private static func handleSecurityViolation(_ violation: SecurityViolation) {
        NSLog("RuntimeProtection: Security violation detected: %@", String(describing: violation))
        
        // Notify security event
        NotificationCenter.default.post(
            name: .securityViolationDetected,
            object: violation
        )
        
        // In production, you might want to:
        // 1. Lock the application
        // 2. Clear sensitive data
        // 3. Exit the application
        // 4. Report to security monitoring service
        
        switch violation {
        case .jailbreakDetected, .debuggerDetected, .codeInjectionDetected:
            // Critical violations - consider immediate app termination
            break
        case .tamperingDetected:
            // Medium severity - clear sensitive data but allow continued use
            break
        case .simulatorDetected:
            // Low severity in development, high in production
            break
        case .multipleThreats(_), .runtimeThreatDetected:
            // High severity - multiple attack vectors
            break
        }
    }
}

// MARK: - Types

public enum SecurityViolation {
    case jailbreakDetected
    case debuggerDetected
    case codeInjectionDetected
    case tamperingDetected
    case simulatorDetected
    case multipleThreats([String])
    case runtimeThreatDetected
}

// MARK: - Notifications

public extension Notification.Name {
    static let securityViolationDetected = Notification.Name("SecurityViolationDetected")
}