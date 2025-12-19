// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import DeviceKit
import Common
import FirebaseCrashlytics

extension MainRepositoryImpl {
    
    var isMainAppProcess: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex") == false
    }
    
    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
    
    var currentBuildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }
    
    var lastKnownAppVersion: String? {
        userDefaultsDataSource.lastKnownAppVersion
    }
    
    func setLastKnownAppVersion(_ version: String) {
        userDefaultsDataSource.setLastKnownAppVersion(version)
    }
    
    func setCrashlyticsEnabled(_ enabled: Bool) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
        userDefaultsDataSource.setCrashlyticsDisabled(enabled == false)
    }
    
    var isCrashlyticsEnabled: Bool {
        Crashlytics.crashlytics().isCrashlyticsCollectionEnabled()
    }
    
    func initialPermissionStateSetChildren(_ children: [PermissionsStateChildDataControllerProtocol]) {
        initialPermissionStateDataController.set(children: children)
    }
    
    func initialPermissionStateInitialize() {
        initialPermissionStateDataController.initialize()
    }
    
    var appBundleIdentifier: String? {
        Bundle.main.bundleIdentifier
    }
    
    func saveDateOfFirstRun(_ date: Date) {
        userDefaultsDataSource.saveDateOfFirstRun(date)
    }
    
    var dateOfFirstRun: Date? {
        userDefaultsDataSource.dateOfFirstRun
    }
    
    func setActiveSearchEnabled(_ enabled: Bool) {
        userDefaultsDataSource.setActiveSearchEnabled(enabled)
    }
    
    var isActiveSearchEnabled: Bool {
        userDefaultsDataSource.isActiveSearchEnabled
    }
    
    var deviceModelName: String {
        Device.current.description
    }
    
    var deviceName: String {
        let name = UIDevice.current.name
        
        let device = Device.current
        if case Device.unknown = device {
            return name
        } else {
            return "\(device) (\(name))"
        }
    }
    
    var deviceType: DeviceType {
        let device = Device.current
        if device.isPhone {
            return .phone
        } else if device.isPad {
            return .pad
        } else {
            return .unknown
        }
    }
    
    var systemVersion: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }
    
    func readFileData(from url: URL) async -> Data? {
        func readFile() async -> Data? {
            do {
                return try Data(contentsOf: url)
            } catch {
                Log("Error reading file data: \(error)", module: .mainRepository, severity: .error)
                return nil
            }
        }
        if url.startAccessingSecurityScopedResource() {
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            return await readFile()
        } else {
            return await readFile()
        }
    }
    
    func checkFileSize(for url: URL) -> Int? { // divide by 1024 * 1024 to get MB
        func checkFileSize() -> Int? {
            do {
                return try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
            } catch {
                Log("Error reading file size: \(error)", module: .mainRepository, severity: .error)
                return nil
            }
        }
        
        if url.startAccessingSecurityScopedResource() {
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            return checkFileSize()
        } else {
            return checkFileSize()
        }
    }
    
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    func copyFileToLocalIfNeeded(from url: URL) -> URL? {
        func copyFile() -> URL? {
            let fileCoordinator = NSFileCoordinator()
            var error: NSError? = nil

            var resultURL: URL?
            fileCoordinator.coordinate(readingItemAt: url, options: [.withoutChanges], error: &error) { newURL in
                do {
                    let fileManager = FileManager.default
                    let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                    
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    
                    try fileManager.copyItem(at: newURL, to: destinationURL)

                    resultURL = destinationURL

                } catch {
                    Log("Error copying file at: \(url)", module: .mainRepository, severity: .error)
                }
            }
            
            if error != nil {
                Log("Error copying file at: \(url)", module: .mainRepository, severity: .error)
                return nil
            }
            
            return resultURL
        }
         
        if url.startAccessingSecurityScopedResource() {
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            guard fileExists(at: url) == false else {
                return url
            }
            
            return copyFile()
        } else {
            guard fileExists(at: url) == false else {
                return url
            }
            
            return copyFile()
        }
    }
    
    func isDirectory(at url: URL) -> Bool? {
        try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
    }

    func readLocalFile(at url: URL) -> Data? {
        FileManager.default.contents(atPath: url.path)
    }

    func readFilesFromFolder(at folderURL: URL, withExtension ext: String, maxFileSize: Int) -> [String: Data]? {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var files: [String: Data] = [:]

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == ext.lowercased(),
                  let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }

            guard let localURL = copyFileToLocalIfNeeded(from: fileURL),
                  let fileSize = checkFileSize(for: localURL),
                  fileSize < maxFileSize,
                  let data = readLocalFile(at: localURL) else {
                continue
            }

            files[fileURL.lastPathComponent.lowercased()] = data
        }

        return files
    }
    
    var is2FASAuthInstalled: Bool {
        UIApplication.shared.canOpenURL(Config.twofasAuthCheckLink)
    }
    
    var lastAppUpdatePromptDate: Date? {
        userDefaultsDataSource.lastAppUpdatePromptDate
    }
    
    func setLastAppUpdatePromptDate(_ date: Date) {
        userDefaultsDataSource.setLastAppUpdatePromptDate(date)
    }
    
    func clearLastAppUpdatePromptDate() {
        userDefaultsDataSource.clearLastAppUpdatePromptDate()
    }
    
    var minimalAppVersionSupported: String? {
        _minimalAppVersionSupported
    }
    
    func setMinimalAppVersionSupported(_ version: String) {
        _minimalAppVersionSupported = version
    }
    
    func clearMinimalAppVersionSupported() {
        _minimalAppVersionSupported = nil
    }
}
