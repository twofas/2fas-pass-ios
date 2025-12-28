// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import OSLog
import FirebaseCrashlytics

public enum LogModule: Int, CaseIterable {
    case unknown = 0
    case storage = 1
    case cloudSync = 2
    case network = 3
    case camera = 4
    case mainRepository = 5
    case protection = 6
    case ui = 7
    case appEvent = 8
    case interactor = 9
    case moduleInteractor = 10
    case backup = 11
    case autofill = 12
    case connect = 13
    case migration = 14
}

public enum LogSeverity: Int, CaseIterable {
    case unknown = 0
    case error = 1
    case warning = 2
    case info = 3
    case trace = 4
}

var focusOn: [LogModule]?

public func Log(
    _ content: LogMessage,
    module: LogModule = .unknown,
    severity: LogSeverity = .unknown,
    save: Bool = true,
    file: String = #file,
    function: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    if let focusOn {
        guard focusOn.contains(module) else { return }
    }
    let date = Date()
    
    if save {
        LogStorage.store(content: content.description, timestamp: date, module: module, severity: severity)
        Crashlytics.crashlytics().log(content.description)
    }
    
#if DEBUG
    let filename = URL(string: file)?.lastPathComponent ?? ""
    let formattedContent = "\(content.description) | \(function) + \(line) (\(filename)) "
    LogPrinter.printLog(content: formattedContent, timestamp: date, module: module, severity: severity)
#endif
}

public func LogZoneStart() {
    LogStorage.markZoneStart()
}

public func LogZoneEnd() {
    LogStorage.markZoneEnd()
}

public func LogSave() {
    LogStorage.save()
}

private extension LogModule {
    var suffix: String {
        switch self {
        case .unknown: "💡"
        case .storage: "💾"
        case .cloudSync: "☁️"
        case .network: "📡"
        case .camera: "📷"
        case .mainRepository: "📖"
        case .protection: "🔒"
        case .ui: "🖼"
        case .appEvent: "🧬"
        case .interactor: "🔌"
        case .moduleInteractor: "🌀"
        case .backup: "🗄️"
        case .autofill: "📝"
        case .connect: "🔗"
        case .migration: "🔄"
        }
    }
}

private extension LogSeverity {
    var suffix: String {
        switch self {
        case .unknown: return "❔"
        case .error: return "❌"
        case .warning: return "⚠️"
        case .info: return "ℹ️"
        case .trace: return "💬"
        }
    }
}

public protocol LogStorageHandling: AnyObject {
    func store(content: String, timestamp: Date, module: Int, severity: Int)
    func markZoneStart()
    func markZoneEnd()
    func removeAll()
    func save()
}

public enum LogPrinter {
    private static var dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate, .withSpaceBetweenDateAndTime, .withTime, .withColonSeparatorInTime
        ]
        return formatter
    }()
    static func printLog(content: String, timestamp: Date, module: LogModule, severity: LogSeverity) {
        let formatted = format(content: content, timestamp: timestamp, module: module, severity: severity)
        print(formatted)
    }
    public static func format(content: String, timestamp: Date, module: LogModule, severity: LogSeverity) -> String {
        "\(dateFormatter.string(from: timestamp))\t\(severity.suffix)\(module.suffix)\t\(content)"
    }
    public static func formatParts(content: String, timestamp: Date, module: LogModule, severity: LogSeverity) ->
    (date: String, icons: String, content: String) {
        (date: dateFormatter.string(from: timestamp), icons: "\(severity.suffix)\(module.suffix)", content: content)
    }
}

public enum LogStorage {
    private static var storage: LogStorageHandling?
    
    public static func setStorage(_ logStorage: LogStorageHandling) {
        storage = logStorage
    }
    
    public static func markZoneStart() {
        storage?.markZoneStart()
    }
    
    public static func markZoneEnd() {
        storage?.markZoneEnd()
    }
    
    public static func save() {
        storage?.save()
    }

    static func store(content: String, timestamp: Date, module: LogModule, severity: LogSeverity) {
        storage?.store(content: content, timestamp: timestamp, module: module.rawValue, severity: severity.rawValue)
    }
}

public enum LogPrivacy {
    case auto
    case `public`
    case `private`
}

public struct LogMessage: ExpressibleByStringInterpolation, CustomStringConvertible {
    public typealias Interpolation = LogInterpolation
    
    private let value: String
    
    public var description: String {
        value
    }
    
    public init(stringLiteral value: String) {
        self.value = value
    }

    public init(stringInterpolation: Interpolation) {
        self.value = stringInterpolation.description
    }
}

public struct LogInterpolation: StringInterpolationProtocol {
    
    public typealias StringLiteralType = String

    private var _interpolation: String.StringInterpolation
    
    var description: String {
        _interpolation.description
    }
    
    public init(literalCapacity: Int, interpolationCount: Int) {
        _interpolation = String.StringInterpolation(literalCapacity: literalCapacity, interpolationCount: interpolationCount)
    }
    
    public mutating func appendLiteral(_ literal: String) {
        _interpolation.appendLiteral(literal)
    }
    
    public mutating func appendInterpolation(_ value: @autoclosure () -> String, privacy: LogPrivacy = .auto) {
        #if PROD
        let shouldHide: Bool = {
            switch privacy {
            case .auto, .private: return true
            case .public: return false
            }
        }()
        let interpolation = shouldHide ? "<private>" : "\(value())"
        #else
        let interpolation = "\(value())"
        #endif
        
        _interpolation.appendInterpolation(interpolation)
    }
}

extension LogInterpolation {
    
    public mutating func appendInterpolation<T>(_ value: @autoclosure () -> T, privacy: LogPrivacy = .auto) where T: CustomStringConvertible {
        appendInterpolation("\(value())", privacy: privacy)
    }
}

extension LogInterpolation {
    
    public mutating func appendInterpolation(_ value: @autoclosure () -> Int, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
    
    public mutating func appendInterpolation(_ value: @autoclosure () -> Double, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
    
    public mutating func appendInterpolation(_ value: @autoclosure () -> Bool, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
    
    public mutating func appendInterpolation(_ value: @autoclosure () -> any Error, privacy: LogPrivacy = .auto) {
        let value = value()
        appendInterpolation("\(type(of: value)).\(value)", privacy: privacy == .auto ? .public : privacy)
    }
}
