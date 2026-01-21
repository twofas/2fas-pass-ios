// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Security
import CryptoKit
import LocalAuthentication
import Backup
import Storage
@testable import Data

final class MockMainRepository: MainRepository {

    // MARK: - Default Configuration

    /// Creates a MockMainRepository with default stubs for common testing scenarios.
    /// Includes: selected vault, encryption key, and basic encryption/decryption pass-through.
    static func defaultConfiguration(vaultID: VaultID = UUID()) -> MockMainRepository {
        let keyData = Data(repeating: 0x42, count: 32)
        let mock = MockMainRepository()
        mock
            .withSelectedVault(VaultEncryptedData(
                vaultID: vaultID,
                name: "Test Vault",
                trustedKey: Data(),
                createdAt: Date(),
                updatedAt: Date(),
                isEmpty: false
            ))
            .withGetKey { _, _ in SymmetricKey(data: keyData) }
        return mock
    }

    // MARK: - Call Tracking

    private(set) var methodCalls: [String] = []

    private func recordCall(_ name: String = #function) {
        methodCalls.append(name)
    }

    func resetCalls() {
        methodCalls.removeAll()
    }

    func wasCalled(_ method: String) -> Bool {
        methodCalls.contains(method)
    }

    func callCount(_ method: String) -> Int {
        methodCalls.filter { $0 == method }.count
    }

    // MARK: - Stubbed Properties

    private var stubbedIsMainAppProcess: Bool = true
    var isMainAppProcess: Bool { stubbedIsMainAppProcess }

    @discardableResult
    func withIsMainAppProcess(_ value: Bool) -> Self {
        stubbedIsMainAppProcess = value
        return self
    }

    // MARK: AutoFill

    private var stubbedIsAutoFillEnabled: Bool = false
    var isAutoFillEnabled: Bool { stubbedIsAutoFillEnabled }

    @discardableResult
    func withIsAutoFillEnabled(_ value: Bool) -> Self {
        stubbedIsAutoFillEnabled = value
        return self
    }

    private var stubbedDidAutoFillStatusChanged: NotificationCenter.Notifications?
    var didAutoFillStatusChanged: NotificationCenter.Notifications {
        stubbedDidAutoFillStatusChanged ?? NotificationCenter.default.notifications(named: .init("MockAutoFillChanged"))
    }

    @discardableResult
    func withDidAutoFillStatusChanged(_ value: NotificationCenter.Notifications?) -> Self {
        stubbedDidAutoFillStatusChanged = value
        return self
    }

    private var stubbedRefreshAutoFillStatus: () async -> Bool = { false }
    @discardableResult
    func refreshAutoFillStatus() async -> Bool {
        recordCall()
        return await stubbedRefreshAutoFillStatus()
    }

    @discardableResult
    func withRefreshAutoFillStatus(_ handler: @escaping () async -> Bool) -> Self {
        stubbedRefreshAutoFillStatus = handler
        return self
    }

    @MainActor @available(iOS 18, *)
    func requestAutoFillPermissions() async {
        recordCall()
    }

    // MARK: Push Notifications

    private var stubbedIsPushNotificationsEnabled: Bool = false
    var isPushNotificationsEnabled: Bool { stubbedIsPushNotificationsEnabled }

    @discardableResult
    func withIsPushNotificationsEnabled(_ value: Bool) -> Self {
        stubbedIsPushNotificationsEnabled = value
        return self
    }

    private var stubbedDidPushNotificationsStatusChanged: NotificationCenter.Notifications?
    var didPushNotificationsStatusChanged: NotificationCenter.Notifications {
        stubbedDidPushNotificationsStatusChanged ?? NotificationCenter.default.notifications(named: .init("MockPushChanged"))
    }

    @discardableResult
    func withDidPushNotificationsStatusChanged(_ value: NotificationCenter.Notifications?) -> Self {
        stubbedDidPushNotificationsStatusChanged = value
        return self
    }

    private var stubbedRefreshPushNotificationsStatus: () async -> Bool = { false }
    @discardableResult
    func refreshPushNotificationsStatus() async -> Bool {
        recordCall()
        return await stubbedRefreshPushNotificationsStatus()
    }

    @discardableResult
    func withRefreshPushNotificationsStatus(_ handler: @escaping () async -> Bool) -> Self {
        stubbedRefreshPushNotificationsStatus = handler
        return self
    }

    private var stubbedCanRequestPushNotificationsPermissions: Bool = true
    var canRequestPushNotificationsPermissions: Bool { stubbedCanRequestPushNotificationsPermissions }

    @discardableResult
    func withCanRequestPushNotificationsPermissions(_ value: Bool) -> Self {
        stubbedCanRequestPushNotificationsPermissions = value
        return self
    }

    func requestPushNotificationsPermissions() async {
        recordCall()
    }

    private var stubbedPushNotificationToken: String?
    var pushNotificationToken: String? { stubbedPushNotificationToken }

    @discardableResult
    func withPushNotificationToken(_ value: String?) -> Self {
        stubbedPushNotificationToken = value
        return self
    }

    private(set) var capturedPushNotificationToken: String?
    func savePushNotificationToken(_ token: String?) {
        recordCall()
        capturedPushNotificationToken = token
    }

    // MARK: Security

    private var stubbedIsUserLoggedIn: Bool = false
    var isUserLoggedIn: Bool { stubbedIsUserLoggedIn }

    @discardableResult
    func withIsUserLoggedIn(_ value: Bool) -> Self {
        stubbedIsUserLoggedIn = value
        return self
    }

    private var stubbedIsAppInBackground: Bool = false
    var isAppInBackground: Bool { stubbedIsAppInBackground }

    @discardableResult
    func withIsAppInBackground(_ value: Bool) -> Self {
        stubbedIsAppInBackground = value
        return self
    }

    private(set) var capturedIsAppInBackground: Bool?
    func setIsAppInBackground(_ isInBackground: Bool) {
        recordCall()
        capturedIsAppInBackground = isInBackground
    }

    private var stubbedIsOnboardingCompleted: Bool = false
    var isOnboardingCompleted: Bool { stubbedIsOnboardingCompleted }

    @discardableResult
    func withIsOnboardingCompleted(_ value: Bool) -> Self {
        stubbedIsOnboardingCompleted = value
        return self
    }

    func finishOnboarding() {
        recordCall()
    }

    private var stubbedIsConnectOnboardingCompleted: Bool = false
    var isConnectOnboardingCompleted: Bool { stubbedIsConnectOnboardingCompleted }

    @discardableResult
    func withIsConnectOnboardingCompleted(_ value: Bool) -> Self {
        stubbedIsConnectOnboardingCompleted = value
        return self
    }

    func finishConnectOnboarding() {
        recordCall()
    }

    private var stubbedShouldShowQuickSetup: Bool = false
    var shouldShowQuickSetup: Bool { stubbedShouldShowQuickSetup }

    @discardableResult
    func withShouldShowQuickSetup(_ value: Bool) -> Self {
        stubbedShouldShowQuickSetup = value
        return self
    }

    private(set) var capturedShouldShowQuickSetup: Bool?
    func setShouldShowQuickSetup(_ value: Bool) {
        recordCall()
        capturedShouldShowQuickSetup = value
    }

    private var stubbedLastAppUpdatePromptDate: Date?
    var lastAppUpdatePromptDate: Date? { stubbedLastAppUpdatePromptDate }

    @discardableResult
    func withLastAppUpdatePromptDate(_ value: Date?) -> Self {
        stubbedLastAppUpdatePromptDate = value
        return self
    }

    private(set) var capturedLastAppUpdatePromptDate: Date?
    func setLastAppUpdatePromptDate(_ date: Date) {
        recordCall()
        capturedLastAppUpdatePromptDate = date
    }

    func clearLastAppUpdatePromptDate() {
        recordCall()
    }

    private var stubbedMinimalAppVersionSupported: String?
    var minimalAppVersionSupported: String? { stubbedMinimalAppVersionSupported }

    @discardableResult
    func withMinimalAppVersionSupported(_ value: String?) -> Self {
        stubbedMinimalAppVersionSupported = value
        return self
    }

    private(set) var capturedMinimalAppVersionSupported: String?
    func setMinimalAppVersionSupported(_ version: String) {
        recordCall()
        capturedMinimalAppVersionSupported = version
    }

    func clearMinimalAppVersionSupported() {
        recordCall()
    }

    // MARK: Biometry

    private var stubbedBiometryType: BiometryType = .missing
    var biometryType: BiometryType { stubbedBiometryType }

    @discardableResult
    func withBiometryType(_ value: BiometryType) -> Self {
        stubbedBiometryType = value
        return self
    }

    private var stubbedIsBiometryEnabled: Bool = false
    var isBiometryEnabled: Bool { stubbedIsBiometryEnabled }

    @discardableResult
    func withIsBiometryEnabled(_ value: Bool) -> Self {
        stubbedIsBiometryEnabled = value
        return self
    }

    private var stubbedIsBiometryAvailable: Bool = true
    var isBiometryAvailable: Bool { stubbedIsBiometryAvailable }

    @discardableResult
    func withIsBiometryAvailable(_ value: Bool) -> Self {
        stubbedIsBiometryAvailable = value
        return self
    }

    private var stubbedIsBiometryLockedOut: Bool = false
    var isBiometryLockedOut: Bool { stubbedIsBiometryLockedOut }

    @discardableResult
    func withIsBiometryLockedOut(_ value: Bool) -> Self {
        stubbedIsBiometryLockedOut = value
        return self
    }

    func disableBiometry() {
        recordCall()
    }

    func reloadAuthContext() {
        recordCall()
    }

    private(set) var capturedBiometryFingerprint: Data?
    func saveBiometryFingerprint(_ data: Data) {
        recordCall()
        capturedBiometryFingerprint = data
    }

    func clearBiometryFingerpring() {
        recordCall()
    }

    private var stubbedBiometryFingerpring: Data?
    var biometryFingerpring: Data? { stubbedBiometryFingerpring }

    @discardableResult
    func withBiometryFingerpring(_ value: Data?) -> Self {
        stubbedBiometryFingerpring = value
        return self
    }

    private var stubbedAuthenticateUsingBiometry: (String) -> BiometricAuthResult = { _ in .success(fingerprint: nil) }
    func authenticateUsingBiometry(reason: String, completion: @escaping (BiometricAuthResult) -> Void) {
        recordCall()
        completion(stubbedAuthenticateUsingBiometry(reason))
    }

    @discardableResult
    func withAuthenticateUsingBiometry(_ handler: @escaping (String) -> BiometricAuthResult) -> Self {
        stubbedAuthenticateUsingBiometry = handler
        return self
    }

    private var stubbedRequestedForBiometryToLogin: Bool = false
    var requestedForBiometryToLogin: Bool { stubbedRequestedForBiometryToLogin }

    @discardableResult
    func withRequestedForBiometryToLogin(_ value: Bool) -> Self {
        stubbedRequestedForBiometryToLogin = value
        return self
    }

    private(set) var capturedRequestedForBiometryToLogin: Bool?
    func setRequestedForBiometryToLogin(_ requested: Bool) {
        recordCall()
        capturedRequestedForBiometryToLogin = requested
    }

    // MARK: App Lock

    private var stubbedAppLockAttempts: AppLockAttempts = .noLimit
    var appLockAttempts: AppLockAttempts { stubbedAppLockAttempts }

    @discardableResult
    func withAppLockAttempts(_ value: AppLockAttempts) -> Self {
        stubbedAppLockAttempts = value
        return self
    }

    private(set) var capturedAppLockAttempts: AppLockAttempts?
    func setAppLockAttempts(_ value: AppLockAttempts) {
        recordCall()
        capturedAppLockAttempts = value
    }

    private var stubbedAppLockBlockTime: AppLockBlockTime?
    var appLockBlockTime: AppLockBlockTime? { stubbedAppLockBlockTime }

    @discardableResult
    func withAppLockBlockTime(_ value: AppLockBlockTime?) -> Self {
        stubbedAppLockBlockTime = value
        return self
    }

    private(set) var capturedAppLockBlockTime: AppLockBlockTime?
    func setAppLockBlockTime(_ value: AppLockBlockTime) {
        recordCall()
        capturedAppLockBlockTime = value
    }

    func clearAppLockBlockTime() {
        recordCall()
    }

    private var stubbedLockAppUntil: Date?
    var lockAppUntil: Date? { stubbedLockAppUntil }

    @discardableResult
    func withLockAppUntil(_ value: Date?) -> Self {
        stubbedLockAppUntil = value
        return self
    }

    private(set) var capturedLockAppUntilDate: Date?
    func setLockAppUntil(date: Date) {
        recordCall()
        capturedLockAppUntilDate = date
    }

    func clearLockAppUntil() {
        recordCall()
    }

    private var stubbedIncorrectLoginCountAttemp: Int = 0
    var incorrectLoginCountAttemp: Int { stubbedIncorrectLoginCountAttemp }

    @discardableResult
    func withIncorrectLoginCountAttemp(_ value: Int) -> Self {
        stubbedIncorrectLoginCountAttemp = value
        return self
    }

    private(set) var capturedIncorrectLoginCountAttempt: Int?
    func setIncorrectLoginCountAttempt(_ count: Int) {
        recordCall()
        capturedIncorrectLoginCountAttempt = count
    }

    func clearIncorrectLoginCountAttempt() {
        recordCall()
    }

    private var stubbedIncorrectBiometryCountAttemp: Int = 0
    var incorrectBiometryCountAttemp: Int { stubbedIncorrectBiometryCountAttemp }

    @discardableResult
    func withIncorrectBiometryCountAttemp(_ value: Int) -> Self {
        stubbedIncorrectBiometryCountAttemp = value
        return self
    }

    private(set) var capturedIncorrectBiometryCountAttempt: Int?
    func setIncorrectBiometryCountAttempt(_ count: Int) {
        recordCall()
        capturedIncorrectBiometryCountAttempt = count
    }

    func clearIncorrectBiometryCountAttempt() {
        recordCall()
    }

    // MARK: General

    private var stubbedCurrentAppVersion: String = "1.0.0"
    var currentAppVersion: String { stubbedCurrentAppVersion }

    @discardableResult
    func withCurrentAppVersion(_ value: String) -> Self {
        stubbedCurrentAppVersion = value
        return self
    }

    private var stubbedCurrentBuildVersion: String = "1"
    var currentBuildVersion: String { stubbedCurrentBuildVersion }

    @discardableResult
    func withCurrentBuildVersion(_ value: String) -> Self {
        stubbedCurrentBuildVersion = value
        return self
    }

    private var stubbedLastKnownAppVersion: String?
    var lastKnownAppVersion: String? { stubbedLastKnownAppVersion }

    @discardableResult
    func withLastKnownAppVersion(_ value: String?) -> Self {
        stubbedLastKnownAppVersion = value
        return self
    }

    private(set) var capturedLastKnownAppVersion: String?
    func setLastKnownAppVersion(_ version: String) {
        recordCall()
        capturedLastKnownAppVersion = version
    }

    private(set) var capturedCrashlyticsEnabled: Bool?
    func setCrashlyticsEnabled(_ enabled: Bool) {
        recordCall()
        capturedCrashlyticsEnabled = enabled
    }

    private var stubbedIsCrashlyticsEnabled: Bool = false
    var isCrashlyticsEnabled: Bool { stubbedIsCrashlyticsEnabled }

    @discardableResult
    func withIsCrashlyticsEnabled(_ value: Bool) -> Self {
        stubbedIsCrashlyticsEnabled = value
        return self
    }

    func initialPermissionStateSetChildren(_ children: [PermissionsStateChildDataControllerProtocol]) {
        recordCall()
    }

    func initialPermissionStateInitialize() {
        recordCall()
    }

    private var stubbedAppBundleIdentifier: String? = "com.test.mock"
    var appBundleIdentifier: String? { stubbedAppBundleIdentifier }

    @discardableResult
    func withAppBundleIdentifier(_ value: String?) -> Self {
        stubbedAppBundleIdentifier = value
        return self
    }

    private var stubbedDateOfFirstRun: Date?
    var dateOfFirstRun: Date? { stubbedDateOfFirstRun }

    @discardableResult
    func withDateOfFirstRun(_ value: Date?) -> Self {
        stubbedDateOfFirstRun = value
        return self
    }

    private(set) var capturedDateOfFirstRun: Date?
    func saveDateOfFirstRun(_ date: Date) {
        recordCall()
        capturedDateOfFirstRun = date
    }

    private(set) var capturedActiveSearchEnabled: Bool?
    func setActiveSearchEnabled(_ enabled: Bool) {
        recordCall()
        capturedActiveSearchEnabled = enabled
    }

    private var stubbedIsActiveSearchEnabled: Bool = false
    var isActiveSearchEnabled: Bool { stubbedIsActiveSearchEnabled }

    @discardableResult
    func withIsActiveSearchEnabled(_ value: Bool) -> Self {
        stubbedIsActiveSearchEnabled = value
        return self
    }

    private var stubbedJsonEncoder: JSONEncoder = JSONEncoder()
    var jsonEncoder: JSONEncoder { stubbedJsonEncoder }

    @discardableResult
    func withJsonEncoder(_ value: JSONEncoder) -> Self {
        stubbedJsonEncoder = value
        return self
    }

    private var stubbedJsonDecoder: JSONDecoder = JSONDecoder()
    var jsonDecoder: JSONDecoder { stubbedJsonDecoder }

    @discardableResult
    func withJsonDecoder(_ value: JSONDecoder) -> Self {
        stubbedJsonDecoder = value
        return self
    }

    private var stubbedCloudSync: CloudSync = CloudSync()
    var cloudSync: CloudSync { stubbedCloudSync }

    @discardableResult
    func withCloudSync(_ value: CloudSync) -> Self {
        stubbedCloudSync = value
        return self
    }

    private var stubbedDeviceName: String = "Mock Device"
    var deviceName: String { stubbedDeviceName }

    @discardableResult
    func withDeviceName(_ value: String) -> Self {
        stubbedDeviceName = value
        return self
    }

    private var stubbedDeviceModelName: String = "Mock Model"
    var deviceModelName: String { stubbedDeviceModelName }

    @discardableResult
    func withDeviceModelName(_ value: String) -> Self {
        stubbedDeviceModelName = value
        return self
    }

    private var stubbedDeviceType: DeviceType = .phone
    var deviceType: DeviceType { stubbedDeviceType }

    @discardableResult
    func withDeviceType(_ value: DeviceType) -> Self {
        stubbedDeviceType = value
        return self
    }

    private var stubbedSystemVersion: String = "17.0"
    var systemVersion: String { stubbedSystemVersion }

    @discardableResult
    func withSystemVersion(_ value: String) -> Self {
        stubbedSystemVersion = value
        return self
    }

    // MARK: File Operations

    private var stubbedCheckFileSize: (URL) -> Int? = { _ in nil }
    func checkFileSize(for url: URL) -> Int? {
        recordCall()
        return stubbedCheckFileSize(url)
    }

    @discardableResult
    func withCheckFileSize(_ handler: @escaping (URL) -> Int?) -> Self {
        stubbedCheckFileSize = handler
        return self
    }

    private var stubbedReadFileData: (URL) async -> Data? = { _ in nil }
    func readFileData(from url: URL) async -> Data? {
        recordCall()
        return await stubbedReadFileData(url)
    }

    @discardableResult
    func withReadFileData(_ handler: @escaping (URL) async -> Data?) -> Self {
        stubbedReadFileData = handler
        return self
    }

    private var stubbedFileExists: (URL) -> Bool = { _ in false }
    func fileExists(at url: URL) -> Bool {
        recordCall()
        return stubbedFileExists(url)
    }

    @discardableResult
    func withFileExists(_ handler: @escaping (URL) -> Bool) -> Self {
        stubbedFileExists = handler
        return self
    }

    private var stubbedCopyFileToLocalIfNeeded: (URL) -> URL? = { _ in nil }
    func copyFileToLocalIfNeeded(from url: URL) -> URL? {
        recordCall()
        return stubbedCopyFileToLocalIfNeeded(url)
    }

    @discardableResult
    func withCopyFileToLocalIfNeeded(_ handler: @escaping (URL) -> URL?) -> Self {
        stubbedCopyFileToLocalIfNeeded = handler
        return self
    }

    private var stubbedIsDirectory: (URL) -> Bool? = { _ in nil }
    func isDirectory(at url: URL) -> Bool? {
        recordCall()
        return stubbedIsDirectory(url)
    }

    @discardableResult
    func withIsDirectory(_ handler: @escaping (URL) -> Bool?) -> Self {
        stubbedIsDirectory = handler
        return self
    }

    private var stubbedReadFilesFromFolder: (URL, String, Int) -> [String: Data]? = { _, _, _ in nil }
    func readFilesFromFolder(at url: URL, withExtension ext: String, maxFileSize: Int) -> [String: Data]? {
        recordCall()
        return stubbedReadFilesFromFolder(url, ext, maxFileSize)
    }

    @discardableResult
    func withReadFilesFromFolder(_ handler: @escaping (URL, String, Int) -> [String: Data]?) -> Self {
        stubbedReadFilesFromFolder = handler
        return self
    }

    private var stubbedReadLocalFile: (URL) -> Data? = { _ in nil }
    func readLocalFile(at url: URL) -> Data? {
        recordCall()
        return stubbedReadLocalFile(url)
    }

    @discardableResult
    func withReadLocalFile(_ handler: @escaping (URL) -> Data?) -> Self {
        stubbedReadLocalFile = handler
        return self
    }

    private var stubbedIs2FASAuthInstalled: Bool = false
    var is2FASAuthInstalled: Bool { stubbedIs2FASAuthInstalled }

    @discardableResult
    func withIs2FASAuthInstalled(_ value: Bool) -> Self {
        stubbedIs2FASAuthInstalled = value
        return self
    }

    // MARK: Encryption

    private var stubbedDeviceID: UUID?
    var deviceID: UUID? { stubbedDeviceID }

    @discardableResult
    func withDeviceID(_ value: UUID?) -> Self {
        stubbedDeviceID = value
        return self
    }

    private(set) var capturedDeviceID: UUID?
    func saveDeviceID(_ deviceID: UUID) {
        recordCall()
        capturedDeviceID = deviceID
    }

    func clearDeviceID() {
        recordCall()
    }

    private var stubbedGenerateUUID: () -> UUID = { UUID() }
    func generateUUID() -> UUID {
        recordCall()
        return stubbedGenerateUUID()
    }

    @discardableResult
    func withGenerateUUID(_ handler: @escaping () -> UUID) -> Self {
        stubbedGenerateUUID = handler
        return self
    }

    private var stubbedGenerateEntropy: () -> Data? = { nil }
    func generateEntropy() -> Data? {
        recordCall()
        return stubbedGenerateEntropy()
    }

    @discardableResult
    func withGenerateEntropy(_ handler: @escaping () -> Data?) -> Self {
        stubbedGenerateEntropy = handler
        return self
    }

    private var stubbedCreateSeed: (Data) -> Seed = { $0 }
    func createSeed(from entropy: Data) -> Seed {
        recordCall()
        return stubbedCreateSeed(entropy)
    }

    @discardableResult
    func withCreateSeed(_ handler: @escaping (Data) -> Seed) -> Self {
        stubbedCreateSeed = handler
        return self
    }

    private var stubbedCreateCRC: (Data) -> UInt8 = { _ in 0 }
    func createCRC(from data: Data) -> UInt8 {
        recordCall()
        return stubbedCreateCRC(data)
    }

    @discardableResult
    func withCreateCRC(_ handler: @escaping (Data) -> UInt8) -> Self {
        stubbedCreateCRC = handler
        return self
    }

    private var stubbedCreate11BitPacks: (Data, Data) -> [Int] = { _, _ in [] }
    func create11BitPacks(from entropy: Data, seed: Data) -> [Int] {
        recordCall()
        return stubbedCreate11BitPacks(entropy, seed)
    }

    @discardableResult
    func withCreate11BitPacks(_ handler: @escaping (Data, Data) -> [Int]) -> Self {
        stubbedCreate11BitPacks = handler
        return self
    }

    private var stubbedCreateWords: ([Int]) -> [String]? = { _ in nil }
    func createWords(from bitPacks: [Int]) -> [String]? {
        recordCall()
        return stubbedCreateWords(bitPacks)
    }

    @discardableResult
    func withCreateWords(_ handler: @escaping ([Int]) -> [String]?) -> Self {
        stubbedCreateWords = handler
        return self
    }

    private var stubbedCreateSalt: ([String]) -> Salt? = { _ in nil }
    func createSalt(from words: [String]) -> Salt? {
        recordCall()
        return stubbedCreateSalt(words)
    }

    @discardableResult
    func withCreateSalt(_ handler: @escaping ([String]) -> Salt?) -> Self {
        stubbedCreateSalt = handler
        return self
    }

    private var stubbedHmac: (String, String) -> String? = { _, _ in nil }
    func hmac(key: String, message: String) -> String? {
        recordCall()
        return stubbedHmac(key, message)
    }

    @discardableResult
    func withHmac(_ handler: @escaping (String, String) -> String?) -> Self {
        stubbedHmac = handler
        return self
    }

    private var stubbedNormalizeStringIntoHEXData: (String) -> String? = { $0 }
    func normalizeStringIntoHEXData(_ string: String) -> String? {
        recordCall()
        return stubbedNormalizeStringIntoHEXData(string)
    }

    @discardableResult
    func withNormalizeStringIntoHEXData(_ handler: @escaping (String) -> String?) -> Self {
        stubbedNormalizeStringIntoHEXData = handler
        return self
    }

    private var stubbedGenerateMasterKey: (String, Seed, Salt, KDFSpec) -> Data? = { _, _, _, _ in nil }
    func generateMasterKey(with masterPassword: String, seed: Seed, salt: Salt, kdfSpec: KDFSpec) -> Data? {
        recordCall()
        return stubbedGenerateMasterKey(masterPassword, seed, salt, kdfSpec)
    }

    @discardableResult
    func withGenerateMasterKey(_ handler: @escaping (String, Seed, Salt, KDFSpec) -> Data?) -> Self {
        stubbedGenerateMasterKey = handler
        return self
    }

    private var stubbedIsSecureEnclaveAvailable: Bool = true
    var isSecureEnclaveAvailable: Bool { stubbedIsSecureEnclaveAvailable }

    @discardableResult
    func withIsSecureEnclaveAvailable(_ value: Bool) -> Self {
        stubbedIsSecureEnclaveAvailable = value
        return self
    }

    private var stubbedCreateSecureEnclaveAccessControl: (Bool) -> SecAccessControl? = { _ in nil }
    func createSecureEnclaveAccessControl(needAuth: Bool) -> SecAccessControl? {
        recordCall()
        return stubbedCreateSecureEnclaveAccessControl(needAuth)
    }

    @discardableResult
    func withCreateSecureEnclaveAccessControl(_ handler: @escaping (Bool) -> SecAccessControl?) -> Self {
        stubbedCreateSecureEnclaveAccessControl = handler
        return self
    }

    private var stubbedCreateSecureEnclavePrivateKey: (SecAccessControl) -> Data? = { _ in nil }
    func createSecureEnclavePrivateKey(accessControl: SecAccessControl, completion: @escaping (Data?) -> Void) {
        recordCall()
        completion(stubbedCreateSecureEnclavePrivateKey(accessControl))
    }

    @discardableResult
    func withCreateSecureEnclavePrivateKey(_ handler: @escaping (SecAccessControl) -> Data?) -> Self {
        stubbedCreateSecureEnclavePrivateKey = handler
        return self
    }

    private var stubbedCreateSymmetricKeyFromSecureEnclave: (Data) -> SymmetricKey? = { _ in nil }
    func createSymmetricKeyFromSecureEnclave(from key: Data) -> SymmetricKey? {
        recordCall()
        return stubbedCreateSymmetricKeyFromSecureEnclave(key)
    }

    @discardableResult
    func withCreateSymmetricKeyFromSecureEnclave(_ handler: @escaping (Data) -> SymmetricKey?) -> Self {
        stubbedCreateSymmetricKeyFromSecureEnclave = handler
        return self
    }

    func createSymmetricKey(from key: Data) -> SymmetricKey {
        recordCall()
        return SymmetricKey(data: key)
    }

    private var stubbedGetKey: (Bool, ItemProtectionLevel) -> SymmetricKey? = { _, _ in nil }
    func getKey(isPassword: Bool, protectionLevel: ItemProtectionLevel) -> SymmetricKey? {
        recordCall()
        return stubbedGetKey(isPassword, protectionLevel)
    }

    @discardableResult
    func withGetKey(_ handler: @escaping (Bool, ItemProtectionLevel) -> SymmetricKey?) -> Self {
        stubbedGetKey = handler
        return self
    }

    private var stubbedEncrypt: (Data, SymmetricKey) -> Data? = { data, _ in data }
    func encrypt(_ data: Data, key: SymmetricKey) -> Data? {
        recordCall()
        return stubbedEncrypt(data, key)
    }

    @discardableResult
    func withEncrypt(_ handler: @escaping (Data, SymmetricKey) -> Data?) -> Self {
        stubbedEncrypt = handler
        return self
    }

    private var stubbedDecrypt: (Data, SymmetricKey) -> Data? = { data, _ in data }
    func decrypt(_ data: Data, key: SymmetricKey) -> Data? {
        recordCall()
        return stubbedDecrypt(data, key)
    }

    @discardableResult
    func withDecrypt(_ handler: @escaping (Data, SymmetricKey) -> Data?) -> Self {
        stubbedDecrypt = handler
        return self
    }

    private var stubbedEncryptWithNonce: (Data, SymmetricKey, Data) -> Data? = { data, _, _ in data }
    func encrypt(_ data: Data, key: SymmetricKey, nonce: Data) -> Data? {
        recordCall()
        return stubbedEncryptWithNonce(data, key, nonce)
    }

    @discardableResult
    func withEncryptWithNonce(_ handler: @escaping (Data, SymmetricKey, Data) -> Data?) -> Self {
        stubbedEncryptWithNonce = handler
        return self
    }

    private var stubbedGenerateRandom: (Int) -> Data? = { Data(repeating: 0, count: $0) }
    func generateRandom(byteCount: Int) -> Data? {
        recordCall()
        return stubbedGenerateRandom(byteCount)
    }

    @discardableResult
    func withGenerateRandom(_ handler: @escaping (Int) -> Data?) -> Self {
        stubbedGenerateRandom = handler
        return self
    }

    private var stubbedImportBIP0039Words: () -> [String]? = { nil }
    func importBIP0039Words() -> [String]? {
        recordCall()
        return stubbedImportBIP0039Words()
    }

    @discardableResult
    func withImportBIP0039Words(_ handler: @escaping () -> [String]?) -> Self {
        stubbedImportBIP0039Words = handler
        return self
    }

    private var stubbedCreateSeedHashHexForExport: () -> String? = { nil }
    func createSeedHashHexForExport() -> String? {
        recordCall()
        return stubbedCreateSeedHashHexForExport()
    }

    @discardableResult
    func withCreateSeedHashHexForExport(_ handler: @escaping () -> String?) -> Self {
        stubbedCreateSeedHashHexForExport = handler
        return self
    }

    private var stubbedCreateReferenceForExport: () -> String? = { nil }
    func createReferenceForExport() -> String? {
        recordCall()
        return stubbedCreateReferenceForExport()
    }

    @discardableResult
    func withCreateReferenceForExport(_ handler: @escaping () -> String?) -> Self {
        stubbedCreateReferenceForExport = handler
        return self
    }

    private var stubbedIsMasterKeyStored: Bool = false
    var isMasterKeyStored: Bool { stubbedIsMasterKeyStored }

    @discardableResult
    func withIsMasterKeyStored(_ value: Bool) -> Self {
        stubbedIsMasterKeyStored = value
        return self
    }

    private var stubbedDecryptStoredMasterKey: () -> MasterKeyEncrypted? = { nil }
    func decryptStoredMasterKey() -> MasterKeyEncrypted? {
        recordCall()
        return stubbedDecryptStoredMasterKey()
    }

    @discardableResult
    func withDecryptStoredMasterKey(_ handler: @escaping () -> MasterKeyEncrypted?) -> Self {
        stubbedDecryptStoredMasterKey = handler
        return self
    }

    private(set) var capturedMasterKey: MasterKeyEncrypted?
    func saveMasterKey(_ key: MasterKeyEncrypted) {
        recordCall()
        capturedMasterKey = key
    }

    func clearMasterKey() {
        recordCall()
    }

    private var stubbedBiometryKey: BiometryKey?
    var biometryKey: BiometryKey? { stubbedBiometryKey }

    @discardableResult
    func withBiometryKey(_ value: BiometryKey?) -> Self {
        stubbedBiometryKey = value
        return self
    }

    private(set) var capturedBiometryKey: BiometryKey?
    func saveBiometryKey(_ data: BiometryKey) {
        recordCall()
        capturedBiometryKey = data
    }

    func clearBiometryKey() {
        recordCall()
    }

    private var stubbedTrustedKeyFromVault: TrustedKey?
    var trustedKeyFromVault: TrustedKey? { stubbedTrustedKeyFromVault }

    @discardableResult
    func withTrustedKeyFromVault(_ value: TrustedKey?) -> Self {
        stubbedTrustedKeyFromVault = value
        return self
    }

    private var stubbedTrustedKey: TrustedKey?
    var trustedKey: TrustedKey? { stubbedTrustedKey }

    @discardableResult
    func withTrustedKey(_ value: TrustedKey?) -> Self {
        stubbedTrustedKey = value
        return self
    }

    private(set) var capturedTrustedKey: TrustedKey?
    func setTrustedKey(_ data: TrustedKey) {
        recordCall()
        capturedTrustedKey = data
    }

    func clearTrustedKey() {
        recordCall()
    }

    private var stubbedSecureKey: SecureKey?
    var secureKey: SecureKey? { stubbedSecureKey }

    @discardableResult
    func withSecureKey(_ value: SecureKey?) -> Self {
        stubbedSecureKey = value
        return self
    }

    private(set) var capturedSecureKey: SecureKey?
    func setSecureKey(_ data: SecureKey) {
        recordCall()
        capturedSecureKey = data
    }

    func clearSecureKey() {
        recordCall()
    }

    private var stubbedExternalKey: ExternalKey?
    var externalKey: ExternalKey? { stubbedExternalKey }

    @discardableResult
    func withExternalKey(_ value: ExternalKey?) -> Self {
        stubbedExternalKey = value
        return self
    }

    private(set) var capturedExternalKey: ExternalKey?
    func setExternalKey(_ data: ExternalKey) {
        recordCall()
        capturedExternalKey = data
    }

    func clearExternalKey() {
        recordCall()
    }

    private var stubbedCachedExternalKey: SymmetricKey?
    var cachedExternalKey: SymmetricKey? { stubbedCachedExternalKey }

    @discardableResult
    func withCachedExternalKey(_ value: SymmetricKey?) -> Self {
        stubbedCachedExternalKey = value
        return self
    }

    private var stubbedAppKey: AppKey?
    var appKey: AppKey? { stubbedAppKey }

    @discardableResult
    func withAppKey(_ value: AppKey?) -> Self {
        stubbedAppKey = value
        return self
    }

    private(set) var capturedAppKey: AppKey?
    func saveAppKey(_ data: AppKey) {
        recordCall()
        capturedAppKey = data
    }

    func clearAppKey() {
        recordCall()
    }

    private var stubbedSeed: Seed?
    var seed: Seed? { stubbedSeed }

    @discardableResult
    func withSeed(_ value: Seed?) -> Self {
        stubbedSeed = value
        return self
    }

    private(set) var capturedSeed: Seed?
    func setSeed(_ data: Seed) {
        recordCall()
        capturedSeed = data
    }

    func clearSeed() {
        recordCall()
    }

    private var stubbedEntropy: Entropy?
    var entropy: Entropy? { stubbedEntropy }

    @discardableResult
    func withEntropy(_ value: Entropy?) -> Self {
        stubbedEntropy = value
        return self
    }

    private(set) var capturedEntropy: Entropy?
    func setEntropy(_ entropy: Entropy) {
        recordCall()
        capturedEntropy = entropy
    }

    func clearEntropy() {
        recordCall()
    }

    private var stubbedWords: [String]?
    var words: [String]? { stubbedWords }

    @discardableResult
    func withWords(_ value: [String]?) -> Self {
        stubbedWords = value
        return self
    }

    private(set) var capturedWords: [String]?
    func setWords(_ words: [String]) {
        recordCall()
        capturedWords = words
    }

    func clearWords() {
        recordCall()
    }

    private var stubbedSalt: Data?
    var salt: Data? { stubbedSalt }

    @discardableResult
    func withSalt(_ value: Data?) -> Self {
        stubbedSalt = value
        return self
    }

    private(set) var capturedSalt: Data?
    func setSalt(_ salt: Data) {
        recordCall()
        capturedSalt = salt
    }

    func clearSalt() {
        recordCall()
    }

    private var stubbedMasterPassword: MasterPassword?
    var masterPassword: MasterPassword? { stubbedMasterPassword }

    @discardableResult
    func withMasterPassword(_ value: MasterPassword?) -> Self {
        stubbedMasterPassword = value
        return self
    }

    private(set) var capturedMasterPassword: MasterPassword?
    func setMasterPassword(_ masterPassword: MasterPassword) {
        recordCall()
        capturedMasterPassword = masterPassword
    }

    func clearMasterPassword() {
        recordCall()
    }

    private var stubbedEmpheralMasterKey: MasterKey?
    var empheralMasterKey: MasterKey? { stubbedEmpheralMasterKey }

    @discardableResult
    func withEmpheralMasterKey(_ value: MasterKey?) -> Self {
        stubbedEmpheralMasterKey = value
        return self
    }

    private(set) var capturedEmpheralMasterKey: MasterKey?
    func setEmpheralMasterKey(_ masterKey: MasterKey) {
        recordCall()
        capturedEmpheralMasterKey = masterKey
    }

    func clearEmpheralMasterKey() {
        recordCall()
    }

    func clearAllEmphemeral() {
        recordCall()
    }

    private var stubbedHasCachedKeys: () -> Bool = { false }
    func hasCachedKeys() -> Bool {
        recordCall()
        return stubbedHasCachedKeys()
    }

    @discardableResult
    func withHasCachedKeys(_ handler: @escaping () -> Bool) -> Self {
        stubbedHasCachedKeys = handler
        return self
    }

    func preparedCachedKeys() {
        recordCall()
    }

    private var stubbedHasEncryptionReference: Bool = false
    var hasEncryptionReference: Bool { stubbedHasEncryptionReference }

    @discardableResult
    func withHasEncryptionReference(_ value: Bool) -> Self {
        stubbedHasEncryptionReference = value
        return self
    }

    func saveEncryptionReference(_ deviceID: DeviceID, masterKey: MasterKey) {
        recordCall()
    }

    private var stubbedVerifyEncryptionReference: (MasterKey, DeviceID) -> Bool = { _, _ in true }
    func verifyEncryptionReference(using masterKey: MasterKey, with deviceID: DeviceID) -> Bool {
        recordCall()
        return stubbedVerifyEncryptionReference(masterKey, deviceID)
    }

    @discardableResult
    func withVerifyEncryptionReference(_ handler: @escaping (MasterKey, DeviceID) -> Bool) -> Self {
        stubbedVerifyEncryptionReference = handler
        return self
    }

    func clearEncryptionReference() {
        recordCall()
    }

    private var stubbedHasMasterKeyEntropy: Bool = false
    var hasMasterKeyEntropy: Bool { stubbedHasMasterKeyEntropy }

    @discardableResult
    func withHasMasterKeyEntropy(_ value: Bool) -> Self {
        stubbedHasMasterKeyEntropy = value
        return self
    }

    private var stubbedMasterKeyEntropy: Entropy?
    var masterKeyEntropy: Entropy? { stubbedMasterKeyEntropy }

    @discardableResult
    func withMasterKeyEntropy(_ value: Entropy?) -> Self {
        stubbedMasterKeyEntropy = value
        return self
    }

    private(set) var capturedMasterKeyEntropy: Entropy?
    func saveMasterKeyEntropy(_ string: Entropy) {
        recordCall()
        capturedMasterKeyEntropy = string
    }

    func clearMasterKeyEntropy() {
        recordCall()
    }

    private var stubbedGenerateTrustedKeyForVaultID: (VaultID, String) -> String? = { _, _ in nil }
    func generateTrustedKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String? {
        recordCall()
        return stubbedGenerateTrustedKeyForVaultID(vaultID, masterKey)
    }

    @discardableResult
    func withGenerateTrustedKeyForVaultID(_ handler: @escaping (VaultID, String) -> String?) -> Self {
        stubbedGenerateTrustedKeyForVaultID = handler
        return self
    }

    private var stubbedGenerateSecureKeyForVaultID: (VaultID, String) -> String? = { _, _ in nil }
    func generateSecureKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String? {
        recordCall()
        return stubbedGenerateSecureKeyForVaultID(vaultID, masterKey)
    }

    @discardableResult
    func withGenerateSecureKeyForVaultID(_ handler: @escaping (VaultID, String) -> String?) -> Self {
        stubbedGenerateSecureKeyForVaultID = handler
        return self
    }

    private var stubbedGenerateExternalKeyForVaultID: (VaultID, String) -> String? = { _, _ in nil }
    func generateExternalKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String? {
        recordCall()
        return stubbedGenerateExternalKeyForVaultID(vaultID, masterKey)
    }

    @discardableResult
    func withGenerateExternalKeyForVaultID(_ handler: @escaping (VaultID, String) -> String?) -> Self {
        stubbedGenerateExternalKeyForVaultID = handler
        return self
    }

    private var stubbedGenerateExchangeSeedHash: (VaultID, Data) -> String? = { _, _ in nil }
    func generateExchangeSeedHash(_ vaultID: VaultID, using seed: Data) -> String? {
        recordCall()
        return stubbedGenerateExchangeSeedHash(vaultID, seed)
    }

    @discardableResult
    func withGenerateExchangeSeedHash(_ handler: @escaping (VaultID, Data) -> String?) -> Self {
        stubbedGenerateExchangeSeedHash = handler
        return self
    }

    private var stubbedConvertWordsToDecimal: ([String]) -> [Int]? = { _ in nil }
    func convertWordsToDecimal(_ words: [String]) -> [Int]? {
        recordCall()
        return stubbedConvertWordsToDecimal(words)
    }

    @discardableResult
    func withConvertWordsToDecimal(_ handler: @escaping ([String]) -> [Int]?) -> Self {
        stubbedConvertWordsToDecimal = handler
        return self
    }

    private var stubbedCreate11BitPacksFromDecimals: ([Int]) -> [UInt16] = { _ in [] }
    func create11BitPacks(from decimals: [Int]) -> [UInt16] {
        recordCall()
        return stubbedCreate11BitPacksFromDecimals(decimals)
    }

    @discardableResult
    func withCreate11BitPacksFromDecimals(_ handler: @escaping ([Int]) -> [UInt16]) -> Self {
        stubbedCreate11BitPacksFromDecimals = handler
        return self
    }

    private var stubbedCreate4BitPacksFrom11BitPacks: ([UInt16]) -> [UInt8] = { _ in [] }
    func create4BitPacksFrom11BitPacks(_ data: [UInt16]) -> [UInt8] {
        recordCall()
        return stubbedCreate4BitPacksFrom11BitPacks(data)
    }

    @discardableResult
    func withCreate4BitPacksFrom11BitPacks(_ handler: @escaping ([UInt16]) -> [UInt8]) -> Self {
        stubbedCreate4BitPacksFrom11BitPacks = handler
        return self
    }

    private var stubbedConvertWordsTo4BitPacksAndCRC: ([String]) -> (bitPacks: Data, crc: UInt8)? = { _ in nil }
    func convertWordsTo4BitPacksAndCRC(_ words: [String]) -> (bitPacks: Data, crc: UInt8)? {
        recordCall()
        return stubbedConvertWordsTo4BitPacksAndCRC(words)
    }

    @discardableResult
    func withConvertWordsTo4BitPacksAndCRC(_ handler: @escaping ([String]) -> (bitPacks: Data, crc: UInt8)?) -> Self {
        stubbedConvertWordsTo4BitPacksAndCRC = handler
        return self
    }

    // MARK: Storage

    var storageError: ((String) -> Void)?

    // MARK: In Memory Storage

    private var stubbedHasInMemoryStorage: Bool = false
    var hasInMemoryStorage: Bool { stubbedHasInMemoryStorage }

    @discardableResult
    func withHasInMemoryStorage(_ value: Bool) -> Self {
        stubbedHasInMemoryStorage = value
        return self
    }

    func createInMemoryStorage() {
        recordCall()
    }

    func destroyInMemoryStorage() {
        recordCall()
    }

    // MARK: Items

    func createItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        recordCall()
    }

    func createLoginItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) {
        recordCall()
    }

    func createSecureNoteItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?,
        additionalInfo: String?
    ) {
        recordCall()
    }

    func createPaymentCardItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    ) {
        recordCall()
    }

    func updateMetadataItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int
    ) {
        recordCall()
    }

    func updateItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        recordCall()
    }

    func updateLoginItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) {
        recordCall()
    }

    func updateSecureNoteItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?,
        additionalInfo: String?
    ) {
        recordCall()
    }

    func updatePaymentCardItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    ) {
        recordCall()
    }

    func updateItems(_ items: [RawItemData]) {
        recordCall()
    }

    func itemsBatchUpdate(_ items: [RawItemData]) {
        recordCall()
    }

    func metadataItemsBatchUpdate(_ items: [any ItemDataType]) {
        recordCall()
    }

    private var stubbedGetItemEntity: (ItemID, Bool) -> ItemData? = { _, _ in nil }
    func getItemEntity(itemID: ItemID, checkInTrash: Bool) -> ItemData? {
        recordCall()
        return stubbedGetItemEntity(itemID, checkInTrash)
    }

    @discardableResult
    func withGetItemEntity(_ handler: @escaping (ItemID, Bool) -> ItemData?) -> Self {
        stubbedGetItemEntity = handler
        return self
    }

    private var stubbedListItems: (ItemsListOptions) -> [ItemData] = { _ in [] }
    func listItems(options: ItemsListOptions) -> [ItemData] {
        recordCall()
        return stubbedListItems(options)
    }

    @discardableResult
    func withListItems(_ handler: @escaping (ItemsListOptions) -> [ItemData]) -> Self {
        stubbedListItems = handler
        return self
    }

    private var stubbedListTrashedItems: () -> [ItemData] = { [] }
    func listTrashedItems() -> [ItemData] {
        recordCall()
        return stubbedListTrashedItems()
    }

    @discardableResult
    func withListTrashedItems(_ handler: @escaping () -> [ItemData]) -> Self {
        stubbedListTrashedItems = handler
        return self
    }

    func deleteItem(itemID: ItemID) {
        recordCall()
    }

    func deleteAllItems() {
        recordCall()
    }

    func saveStorage() {
        recordCall()
    }

    private var stubbedListUsernames: () -> [String] = { [] }
    func listUsernames() -> [String] {
        recordCall()
        return stubbedListUsernames()
    }

    @discardableResult
    func withListUsernames(_ handler: @escaping () -> [String]) -> Self {
        stubbedListUsernames = handler
        return self
    }

    private var stubbedExtractItemName: (Data) -> String? = { _ in nil }
    func extractItemName(fromContent data: Data) -> String? {
        recordCall()
        return stubbedExtractItemName(data)
    }

    @discardableResult
    func withExtractItemName(_ handler: @escaping (Data) -> String?) -> Self {
        stubbedExtractItemName = handler
        return self
    }

    // MARK: Tags

    func createTag(_ tag: ItemTagData) {
        recordCall()
    }

    func updateTag(_ tag: ItemTagData) {
        recordCall()
    }

    func deleteTag(tagID: ItemTagID) {
        recordCall()
    }

    func deleteAllTags() {
        recordCall()
    }

    private var stubbedListTags: (TagListOptions) -> [ItemTagData] = { _ in [] }
    func listTags(options: TagListOptions) -> [ItemTagData] {
        recordCall()
        return stubbedListTags(options)
    }

    @discardableResult
    func withListTags(_ handler: @escaping (TagListOptions) -> [ItemTagData]) -> Self {
        stubbedListTags = handler
        return self
    }

    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date) {
        recordCall()
    }

    // MARK: Encrypted Storage

    func saveEncryptedStorage() {
        recordCall()
    }

    func createEncryptedItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        recordCall()
    }

    func updateEncryptedItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        recordCall()
    }

    func encryptedItemsBatchUpdate(_ items: [ItemEncryptedData]) {
        recordCall()
    }

    private var stubbedGetEncryptedItemEntity: (ItemID) -> ItemEncryptedData? = { _ in nil }
    func getEncryptedItemEntity(itemID: ItemID) -> ItemEncryptedData? {
        recordCall()
        return stubbedGetEncryptedItemEntity(itemID)
    }

    @discardableResult
    func withGetEncryptedItemEntity(_ handler: @escaping (ItemID) -> ItemEncryptedData?) -> Self {
        stubbedGetEncryptedItemEntity = handler
        return self
    }

    private var stubbedListEncryptedItems: (VaultID) -> [ItemEncryptedData] = { _ in [] }
    func listEncryptedItems(in vaultID: VaultID) -> [ItemEncryptedData] {
        recordCall()
        return stubbedListEncryptedItems(vaultID)
    }

    @discardableResult
    func withListEncryptedItems(_ handler: @escaping (VaultID) -> [ItemEncryptedData]) -> Self {
        stubbedListEncryptedItems = handler
        return self
    }

    private var stubbedListEncryptedItemsFiltered: (VaultID, [ItemID]?, Set<ItemProtectionLevel>?) -> [ItemEncryptedData] = { _, _, _ in [] }
    func listEncryptedItems(
        in vaultID: VaultID,
        itemIDs: [ItemID]?,
        excludeProtectionLevels: Set<ItemProtectionLevel>?
    ) -> [ItemEncryptedData] {
        recordCall()
        return stubbedListEncryptedItemsFiltered(vaultID, itemIDs, excludeProtectionLevels)
    }

    @discardableResult
    func withListEncryptedItemsFiltered(
        _ handler: @escaping (VaultID, [ItemID]?, Set<ItemProtectionLevel>?) -> [ItemEncryptedData]
    ) -> Self {
        stubbedListEncryptedItemsFiltered = handler
        return self
    }

    func addEncryptedItem(_ itemID: ItemID, to vaultID: VaultID) {
        recordCall()
    }

    func deleteEncryptedItem(itemID: ItemID) {
        recordCall()
    }

    func deleteAllEncryptedItems() {
        recordCall()
    }

    private var stubbedRequiresReencryptionMigration: () -> Bool = { false }
    func requiresReencryptionMigration() -> Bool {
        recordCall()
        return stubbedRequiresReencryptionMigration()
    }

    @discardableResult
    func withRequiresReencryptionMigration(_ handler: @escaping () -> Bool) -> Self {
        stubbedRequiresReencryptionMigration = handler
        return self
    }

    func loadEncryptedStore(completion: @escaping Callback) {
        recordCall()
        completion()
    }

    private var stubbedLoadEncryptedStoreWithReencryptionMigration: (@escaping (Bool) -> Void) -> Void = { $0(true) }
    func loadEncryptedStoreWithReencryptionMigration(completion: @escaping (Bool) -> Void) {
        recordCall()
        stubbedLoadEncryptedStoreWithReencryptionMigration(completion)
    }

    @discardableResult
    func withLoadEncryptedStoreWithReencryptionMigration(_ handler: @escaping (@escaping (Bool) -> Void) -> Void) -> Self {
        stubbedLoadEncryptedStoreWithReencryptionMigration = handler
        return self
    }

    // MARK: Encrypted Vaults

    private var stubbedListEncryptedVaults: () -> [VaultEncryptedData] = { [] }
    func listEncryptedVaults() -> [VaultEncryptedData] {
        recordCall()
        return stubbedListEncryptedVaults()
    }

    @discardableResult
    func withListEncryptedVaults(_ handler: @escaping () -> [VaultEncryptedData]) -> Self {
        stubbedListEncryptedVaults = handler
        return self
    }

    private var stubbedGetEncryptedVault: (VaultID) -> VaultEncryptedData? = { _ in nil }
    func getEncryptedVault(for vaultID: VaultID) -> VaultEncryptedData? {
        recordCall()
        return stubbedGetEncryptedVault(vaultID)
    }

    @discardableResult
    func withGetEncryptedVault(_ handler: @escaping (VaultID) -> VaultEncryptedData?) -> Self {
        stubbedGetEncryptedVault = handler
        return self
    }

    func createEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        recordCall()
    }

    func updateEncryptedVault(
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        recordCall()
    }

    func deleteEncryptedVault(_ vaultID: VaultID) {
        recordCall()
    }

    func selectVault(_ vaultID: VaultID) {
        recordCall()
    }

    func clearVault() {
        recordCall()
    }

    func deleteAllVaults() {
        recordCall()
    }

    private var stubbedSelectedVault: VaultEncryptedData?
    var selectedVault: VaultEncryptedData? { stubbedSelectedVault }

    @discardableResult
    func withSelectedVault(_ value: VaultEncryptedData?) -> Self {
        stubbedSelectedVault = value
        return self
    }

    // MARK: Deleted Items

    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        recordCall()
    }

    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        recordCall()
    }

    private var stubbedListDeletedItems: (VaultID, Int?) -> [DeletedItemData] = { _, _ in [] }
    func listDeletedItems(in vaultID: VaultID, limit: Int?) -> [DeletedItemData] {
        recordCall()
        return stubbedListDeletedItems(vaultID, limit)
    }

    @discardableResult
    func withListDeletedItems(_ handler: @escaping (VaultID, Int?) -> [DeletedItemData]) -> Self {
        stubbedListDeletedItems = handler
        return self
    }

    func deleteDeletedItem(id: DeletedItemID) {
        recordCall()
    }

    // MARK: Web Browser

    func createEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        recordCall()
    }

    func updateEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        recordCall()
    }

    func deleteEncryptedWebBrowser(id: UUID) {
        recordCall()
    }

    private var stubbedListEncryptedWebBrowsers: () -> [WebBrowserEncryptedData] = { [] }
    func listEncryptedWebBrowsers() -> [WebBrowserEncryptedData] {
        recordCall()
        return stubbedListEncryptedWebBrowsers()
    }

    @discardableResult
    func withListEncryptedWebBrowsers(_ handler: @escaping () -> [WebBrowserEncryptedData]) -> Self {
        stubbedListEncryptedWebBrowsers = handler
        return self
    }

    // MARK: Encrypted Tags

    func createEncryptedTag(_ tag: ItemTagEncryptedData) {
        recordCall()
    }

    func updateEncryptedTag(_ tag: ItemTagEncryptedData) {
        recordCall()
    }

    func deleteEncryptedTag(tagID: ItemTagID) {
        recordCall()
    }

    private var stubbedListEncryptedTags: (VaultID) -> [ItemTagEncryptedData] = { _ in [] }
    func listEncryptedTags(in vault: VaultID) -> [ItemTagEncryptedData] {
        recordCall()
        return stubbedListEncryptedTags(vault)
    }

    @discardableResult
    func withListEncryptedTags(_ handler: @escaping (VaultID) -> [ItemTagEncryptedData]) -> Self {
        stubbedListEncryptedTags = handler
        return self
    }

    func encryptedTagBatchUpdate(_ tags: [ItemTagEncryptedData], in vault: VaultID) {
        recordCall()
    }

    func deleteAllEncryptedTags(in vault: VaultID) {
        recordCall()
    }

    func deleteAllEncryptedTags() {
        recordCall()
    }

    func listAllEncryptedTags() -> [ItemTagEncryptedData] {
        recordCall()
        return []
    }

    // MARK: Sort

    private var stubbedSortType: SortType?
    var sortType: SortType? { stubbedSortType }

    @discardableResult
    func withSortType(_ value: SortType?) -> Self {
        stubbedSortType = value
        return self
    }

    private(set) var capturedSortType: SortType?
    func setSortType(_ sortType: SortType) {
        recordCall()
        capturedSortType = sortType
    }

    // MARK: Camera

    private var stubbedPermission: CameraPermissionState = .unknown
    var permission: CameraPermissionState { stubbedPermission }

    @discardableResult
    func withPermission(_ value: CameraPermissionState) -> Self {
        stubbedPermission = value
        return self
    }

    private var stubbedIsCameraPresent: Bool = true
    var isCameraPresent: Bool { stubbedIsCameraPresent }

    @discardableResult
    func withIsCameraPresent(_ value: Bool) -> Self {
        stubbedIsCameraPresent = value
        return self
    }

    private var stubbedCheckForPermission: () -> CameraPermissionState = { .unknown }
    func checkForPermission() -> CameraPermissionState {
        recordCall()
        return stubbedCheckForPermission()
    }

    @discardableResult
    func withCheckForPermission(_ handler: @escaping () -> CameraPermissionState) -> Self {
        stubbedCheckForPermission = handler
        return self
    }

    private var stubbedRequestPermission: (@escaping (CameraPermissionState) -> Void) -> Void = { $0(.granted) }
    func requestPermission(result: @escaping (CameraPermissionState) -> Void) {
        recordCall()
        stubbedRequestPermission(result)
    }

    @discardableResult
    func withRequestPermission(_ handler: @escaping (@escaping (CameraPermissionState) -> Void) -> Void) -> Self {
        stubbedRequestPermission = handler
        return self
    }

    // MARK: Cloud

    private var stubbedIsCloudBackupConnected: Bool = false
    var isCloudBackupConnected: Bool { stubbedIsCloudBackupConnected }

    @discardableResult
    func withIsCloudBackupConnected(_ value: Bool) -> Self {
        stubbedIsCloudBackupConnected = value
        return self
    }

    private var stubbedCloudCurrentState: CloudState = .unknown
    var cloudCurrentState: CloudState { stubbedCloudCurrentState }

    @discardableResult
    func withCloudCurrentState(_ value: CloudState) -> Self {
        stubbedCloudCurrentState = value
        return self
    }

    func enableCloudBackup() {
        recordCall()
    }

    func disableCloudBackup() {
        recordCall()
    }

    func clearBackup() {
        recordCall()
    }

    func synchronizeBackup() {
        recordCall()
    }

    private var stubbedCloudListVaultsToRecover: (@escaping (Result<[VaultRawData], Error>) -> Void) -> Void = { $0(.success([])) }
    func cloudListVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void) {
        recordCall()
        stubbedCloudListVaultsToRecover(completion)
    }

    @discardableResult
    func withCloudListVaultsToRecover(_ handler: @escaping (@escaping (Result<[VaultRawData], Error>) -> Void) -> Void) -> Self {
        stubbedCloudListVaultsToRecover = handler
        return self
    }

    private var stubbedCloudDeleteVault: (VaultID) async throws -> Void = { _ in }
    func cloudDeleteVault(id: VaultID) async throws {
        recordCall()
        try await stubbedCloudDeleteVault(id)
    }

    @discardableResult
    func withCloudDeleteVault(_ handler: @escaping (VaultID) async throws -> Void) -> Self {
        stubbedCloudDeleteVault = handler
        return self
    }

    private var stubbedLastSuccessCloudSyncDate: Date?
    var lastSuccessCloudSyncDate: Date? { stubbedLastSuccessCloudSyncDate }

    @discardableResult
    func withLastSuccessCloudSyncDate(_ value: Date?) -> Self {
        stubbedLastSuccessCloudSyncDate = value
        return self
    }

    private(set) var capturedLastSuccessCloudSyncDate: Date?
    func setLastSuccessCloudSyncDate(_ date: Date) {
        recordCall()
        capturedLastSuccessCloudSyncDate = date
    }

    func clearLastSuccessCloudSyncDate() {
        recordCall()
    }

    // MARK: Cloud Cache

    func cloudCacheCreateItem(
        itemID: ItemID,
        content: Data,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        tagIds: [ItemTagID]?,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        metadata: Data
    ) {
        recordCall()
    }

    func cloudCacheUpdateItem(
        itemID: ItemID,
        content: Data,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        tagIds: [ItemTagID]?,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        metadata: Data
    ) {
        recordCall()
    }

    private var stubbedCloudCacheGetItemEntity: (ItemID) -> CloudDataItem? = { _ in nil }
    func cloudCacheGetItemEntity(itemID: ItemID) -> CloudDataItem? {
        recordCall()
        return stubbedCloudCacheGetItemEntity(itemID)
    }

    @discardableResult
    func withCloudCacheGetItemEntity(_ handler: @escaping (ItemID) -> CloudDataItem?) -> Self {
        stubbedCloudCacheGetItemEntity = handler
        return self
    }

    private var stubbedCloudCacheListItems: (VaultID) -> [CloudDataItem] = { _ in [] }
    func cloudCacheListItems(in vaultID: VaultID) -> [CloudDataItem] {
        recordCall()
        return stubbedCloudCacheListItems(vaultID)
    }

    @discardableResult
    func withCloudCacheListItems(_ handler: @escaping (VaultID) -> [CloudDataItem]) -> Self {
        stubbedCloudCacheListItems = handler
        return self
    }

    private var stubbedCloudCacheListAllItems: () -> [CloudDataItem] = { [] }
    func cloudCacheListAllItems() -> [CloudDataItem] {
        recordCall()
        return stubbedCloudCacheListAllItems()
    }

    @discardableResult
    func withCloudCacheListAllItems(_ handler: @escaping () -> [CloudDataItem]) -> Self {
        stubbedCloudCacheListAllItems = handler
        return self
    }

    func cloudCacheDeleteItem(itemID: ItemID) {
        recordCall()
    }

    func cloudCacheDeleteAllItems() {
        recordCall()
    }

    private var stubbedCloudCacheListVaults: () -> [VaultCloudData] = { [] }
    func cloudCacheListVaults() -> [VaultCloudData] {
        recordCall()
        return stubbedCloudCacheListVaults()
    }

    @discardableResult
    func withCloudCacheListVaults(_ handler: @escaping () -> [VaultCloudData]) -> Self {
        stubbedCloudCacheListVaults = handler
        return self
    }

    private var stubbedCloudCacheGetVault: (VaultID) -> VaultCloudData? = { _ in nil }
    func cloudCacheGetVault(for vaultID: VaultID) -> VaultCloudData? {
        recordCall()
        return stubbedCloudCacheGetVault(vaultID)
    }

    @discardableResult
    func withCloudCacheGetVault(_ handler: @escaping (VaultID) -> VaultCloudData?) -> Self {
        stubbedCloudCacheGetVault = handler
        return self
    }

    func cloudCacheCreateVault(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        recordCall()
    }

    func cloudCacheUpdateVault(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        recordCall()
    }

    func cloudCacheDeleteVault(_ vaultID: VaultID) {
        recordCall()
    }

    func cloudCacheDeleteAllVaults() {
        recordCall()
    }

    func cloudCacheCreateDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    ) {
        recordCall()
    }

    func cloudCacheUpdateDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    ) {
        recordCall()
    }

    var stubbedCloudCacheListDeletedItems: [CloudDataDeletedItem] = []
    func cloudCacheListDeletedItems(in vaultID: VaultID, limit: Int?) -> [CloudDataDeletedItem] {
        recordCall()
        if let limit {
            return Array(stubbedCloudCacheListDeletedItems.prefix(limit))
        }
        return stubbedCloudCacheListDeletedItems
    }

    var stubbedCloudCacheListAllDeletedItems: [CloudDataDeletedItem] = []
    func cloudCacheListAllDeletedItems(limit: Int?) -> [CloudDataDeletedItem] {
        recordCall()
        if let limit {
            return Array(stubbedCloudCacheListAllDeletedItems.prefix(limit))
        }
        return stubbedCloudCacheListAllDeletedItems
    }

    func cloudCacheDeleteDeletedItem(itemID: DeletedItemID) {
        recordCall()
    }

    func cloudCacheDeleteAllDeletedItems() {
        recordCall()
    }

    var stubbedCloudCacheIsInitializingNewStore: Bool = false
    var cloudCacheIsInitializingNewStore: Bool { stubbedCloudCacheIsInitializingNewStore }

    func cloudCacheMarkInitializingNewStoreAsHandled() {
        recordCall()
    }

    func cloudCacheCreateTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    ) {
        recordCall()
    }

    func cloudCacheUpdateTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    ) {
        recordCall()
    }

    var stubbedCloudCacheGetTag: CloudDataTagItem?
    func cloudCacheGetTag(tagID: ItemTagID) -> CloudDataTagItem? {
        recordCall()
        return stubbedCloudCacheGetTag
    }

    var stubbedCloudCacheListTags: [CloudDataTagItem] = []
    func cloudCacheListTags(in vaultID: VaultID, limit: Int?) -> [CloudDataTagItem] {
        recordCall()
        if let limit {
            return Array(stubbedCloudCacheListTags.prefix(limit))
        }
        return stubbedCloudCacheListTags
    }

    var stubbedCloudCacheListAllTags: [CloudDataTagItem] = []
    func cloudCacheListAllTags(limit: Int?) -> [CloudDataTagItem] {
        recordCall()
        if let limit {
            return Array(stubbedCloudCacheListAllTags.prefix(limit))
        }
        return stubbedCloudCacheListAllTags
    }

    func cloudCacheDeleteTag(tagID: ItemTagID) {
        recordCall()
    }

    func cloudCacheDeleteAllTags() {
        recordCall()
    }

    func cloudCacheSave() {
        recordCall()
    }

    // MARK: System

    var stubbedSyncHasError: Bool = false
    var syncHasError: Bool { stubbedSyncHasError }

    var capturedSyncHasError: Bool?
    func setSyncHasError(_ value: Bool) {
        recordCall()
        capturedSyncHasError = value
    }

    func copyToClipboard(_ str: String) {
        recordCall()
    }

    func positiveFeedback() {
        recordCall()
    }

    func negativeFeedback() {
        recordCall()
    }

    func warningFeedback() {
        recordCall()
    }

    // MARK: Config

    var stubbedCurrentDefaultProtectionLevel: ItemProtectionLevel = .normal
    var currentDefaultProtectionLevel: ItemProtectionLevel { stubbedCurrentDefaultProtectionLevel }

    var capturedDefaultProtectionLevel: ItemProtectionLevel?
    func setDefaultProtectionLevel(_ value: ItemProtectionLevel) {
        recordCall()
        capturedDefaultProtectionLevel = value
    }

    var stubbedPasswordGeneratorConfig: Data?
    var passwordGeneratorConfig: Data? { stubbedPasswordGeneratorConfig }

    var capturedPasswordGeneratorConfig: Data?
    func setPasswordGeneratorConfig(_ data: Data) {
        recordCall()
        capturedPasswordGeneratorConfig = data
    }

    var stubbedDefaultPassswordListAction: PasswordListAction = .copy
    var defaultPassswordListAction: PasswordListAction { stubbedDefaultPassswordListAction }

    var capturedDefaultPassswordListAction: PasswordListAction?
    func setDefaultPassswordListAction(_ action: PasswordListAction) {
        recordCall()
        capturedDefaultPassswordListAction = action
    }

    // MARK: Network

    var stubbedFetchFile: Result<Data, NetworkError> = .success(Data())
    func fetchFile(from url: URL, completion: @escaping (Result<Data, NetworkError>) -> Void) {
        recordCall()
        completion(stubbedFetchFile)
    }

    var stubbedCachedImage: Data?
    func cachedImage(from url: URL) -> Data? {
        recordCall()
        return stubbedCachedImage
    }

    var stubbedFetchIconImage: Data = Data()
    var stubbedFetchIconImageError: Error?
    func fetchIconImage(from url: URL) async throws -> Data {
        recordCall()
        if let error = stubbedFetchIconImageError {
            throw error
        }
        return stubbedFetchIconImage
    }

    // MARK: Image

    var stubbedResizeImage: Data?
    func resizeImage(from data: Data, to size: CGSize) -> Data? {
        recordCall()
        return stubbedResizeImage ?? data
    }

    // MARK: Logs

    var stubbedListAllLogs: [LogEntry] = []
    func listAllLogs() -> [LogEntry] {
        recordCall()
        return stubbedListAllLogs
    }

    func removeAllLogs() {
        recordCall()
    }

    func removeOldStoreLogs() {
        recordCall()
    }

    // MARK: WebDAV Backup

    var stubbedWebDAVGetIndex: Result<Data, BackupWebDAVSyncError> = .success(Data())
    func webDAVGetIndex(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVGetIndex)
    }

    var stubbedWebDAVGetLock: Result<Data, BackupWebDAVSyncError> = .success(Data())
    func webDAVGetLock(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVGetLock)
    }

    var stubbedWebDAVGetVault: Result<Data, BackupWebDAVSyncError> = .success(Data())
    func webDAVGetVault(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVGetVault)
    }

    var stubbedWebDAVWriteIndex: Result<Void, BackupWebDAVSyncError> = .success(())
    func webDAVWriteIndex(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVWriteIndex)
    }

    var stubbedWebDAVWriteLock: Result<Void, BackupWebDAVSyncError> = .success(())
    func webDAVWriteLock(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVWriteLock)
    }

    var stubbedWebDAVWriteVault: Result<Void, BackupWebDAVSyncError> = .success(())
    func webDAVWriteVault(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVWriteVault)
    }

    var stubbedWebDAVWriteDecryptedVault: Result<Void, BackupWebDAVSyncError> = .success(())
    func webDAVWriteDecryptedVault(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVWriteDecryptedVault)
    }

    var stubbedWebDAVMove: Result<Void, BackupWebDAVSyncError> = .success(())
    func webDAVMove(completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVMove)
    }

    var stubbedWebDAVDeleteLock: Result<Void, BackupWebDAVSyncError> = .success(())
    func webDAVDeleteLock(completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        recordCall()
        completion(stubbedWebDAVDeleteLock)
    }

    func webDAVSetBackupConfig(_ config: BackupWebDAVConfig) {
        recordCall()
    }

    var stubbedWebDAVSavedConfig: BackupWebDAVConfig?
    var webDAVSavedConfig: BackupWebDAVConfig? { stubbedWebDAVSavedConfig }

    var capturedWebDAVSavedConfig: BackupWebDAVConfig?
    func webDAVSaveSavedConfig(_ config: BackupWebDAVConfig) {
        recordCall()
        capturedWebDAVSavedConfig = config
    }

    var stubbedWebDAVEncodeLock: Data?
    func webDAVEncodeLock(timestamp: Int, deviceId: UUID) -> Data? {
        recordCall()
        return stubbedWebDAVEncodeLock
    }

    var stubbedWebDAVDecodeLock: (timestamp: Int, deviceId: UUID)?
    func webDAVDecodeLock(_ data: Data) -> (timestamp: Int, deviceId: UUID)? {
        recordCall()
        return stubbedWebDAVDecodeLock
    }

    var stubbedWebDAVEncodeIndex: Data?
    func webDAVEncodeIndex(_ index: WebDAVIndex) -> Data? {
        recordCall()
        return stubbedWebDAVEncodeIndex
    }

    var stubbedWebDAVDecodeIndex: WebDAVIndex?
    func webDAVDecodeIndex(_ data: Data) -> WebDAVIndex? {
        recordCall()
        return stubbedWebDAVDecodeIndex
    }

    func webDAVClearConfig() {
        recordCall()
    }

    var stubbedWebDAVSeedHash: String?
    var webDAVSeedHash: String? { stubbedWebDAVSeedHash }

    var stubbedWebDAVCurrentVaultID: VaultID?
    var webDAVCurrentVaultID: VaultID? { stubbedWebDAVCurrentVaultID }

    var stubbedWebDAVIsConnected: Bool = false
    var webDAVIsConnected: Bool { stubbedWebDAVIsConnected }

    var capturedWebDAVIsConnected: Bool?
    func webDAVSetIsConnected(_ isConnected: Bool) {
        recordCall()
        capturedWebDAVIsConnected = isConnected
    }

    func webDAVClearIsConnected() {
        recordCall()
    }

    var stubbedWebDAVHasLocalChanges: Bool = false
    var webDAVHasLocalChanges: Bool { stubbedWebDAVHasLocalChanges }

    func webDAVSetHasLocalChanges() {
        recordCall()
    }

    func webDAVClearHasLocalChanges() {
        recordCall()
    }

    var stubbedWebDAVState: WebDAVState = .idle
    var webDAVState: WebDAVState { stubbedWebDAVState }

    var capturedWebDAVState: WebDAVState?
    func webDAVSetState(_ state: WebDAVState) {
        recordCall()
        capturedWebDAVState = state
    }

    func webDAVClearState() {
        recordCall()
    }

    var stubbedWebDAVLastSync: WebDAVLock?
    var webDAVLastSync: WebDAVLock? { stubbedWebDAVLastSync }

    var capturedWebDAVLastSync: WebDAVLock?
    func webDAVSetLastSync(_ lastSync: WebDAVLock) {
        recordCall()
        capturedWebDAVLastSync = lastSync
    }

    func webDAVClearLastSync() {
        recordCall()
    }

    var stubbedWebDAVWriteDecryptedCopy: Bool = false
    var webDAVWriteDecryptedCopy: Bool { stubbedWebDAVWriteDecryptedCopy }

    var capturedWebDAVWriteDecryptedCopy: Bool?
    func webDAVSetWriteDecryptedCopy(_ writeDecryptedCopy: Bool) {
        recordCall()
        capturedWebDAVWriteDecryptedCopy = writeDecryptedCopy
    }

    var stubbedWebDAVAwaitsVaultOverrideAfterPasswordChange: Bool = false
    var webDAVAwaitsVaultOverrideAfterPasswordChange: Bool { stubbedWebDAVAwaitsVaultOverrideAfterPasswordChange }

    var capturedWebDAVAwaitsVaultOverrideAfterPasswordChange: Bool?
    func setWebDAVAwaitsVaultOverrideAfterPasswordChange(_ value: Bool) {
        recordCall()
        capturedWebDAVAwaitsVaultOverrideAfterPasswordChange = value
    }

    // MARK: 2FAS Web Service

    var stubbedAppNotifications: AppNotifications = AppNotifications(notifications: nil, compatibility: nil)
    var stubbedAppNotificationsError: Error?
    func appNotifications() async throws -> AppNotifications {
        recordCall()
        if let error = stubbedAppNotificationsError {
            throw error
        }
        return stubbedAppNotifications
    }

    var stubbedDeleteAppNotificationError: Error?
    func deleteAppNotification(id: String) async throws {
        recordCall()
        if let error = stubbedDeleteAppNotificationError {
            throw error
        }
    }

    // MARK: Scan

    var stubbedScan: Result<[String], ScanImageError> = .success([])
    func scan(image: UIImage, completion: @escaping (Result<[String], ScanImageError>) -> Void) {
        recordCall()
        completion(stubbedScan)
    }

    // MARK: Time offset

    var stubbedTimeOffset: TimeInterval = 0
    var timeOffset: TimeInterval { stubbedTimeOffset }

    var capturedTimeOffset: TimeInterval?
    func setTimeOffset(_ offset: TimeInterval) {
        recordCall()
        capturedTimeOffset = offset
    }

    var stubbedCheckTimeOffset: TimeInterval?
    func checkTimeOffset(completion: @escaping (TimeInterval?) -> Void) {
        recordCall()
        completion(stubbedCheckTimeOffset)
    }

    var stubbedCurrentDate: Date = Date()
    var currentDate: Date { stubbedCurrentDate }

    // MARK: Payment

    var stubbedPaymentUserId: String?
    var paymentUserId: String? { stubbedPaymentUserId }

    var stubbedPaymentSubscriptionPlan: SubscriptionPlan = .free
    var paymentSubscriptionPlan: SubscriptionPlan { stubbedPaymentSubscriptionPlan }

    func paymentInitialize(apiKey: String, debug: Bool) {
        recordCall()
    }

    func paymentRegisterForUserUpdate(_ callback: @escaping () -> Void) {
        recordCall()
    }

    func paymentRegisterForPromotedPurchase(_ callback: @escaping () -> Bool) {
        recordCall()
    }

    func paymentUpdatePaymentStatus(subscriptionName: String) {
        recordCall()
    }

    var stubbedPaymentSubscriptionPrice: String?
    func paymentSubscriptionPrice(subscriptionName: String) async -> String? {
        recordCall()
        return stubbedPaymentSubscriptionPrice
    }

    func paymentRunCachedPromotedPurchase() {
        recordCall()
    }

    var stubbedIsOverridedSubscriptionPlan: Bool = false
    var isOverridedSubscriptionPlan: Bool { stubbedIsOverridedSubscriptionPlan }

    var capturedOverrideSubscriptionPlan: SubscriptionPlan?
    func overrideSubscriptionPlan(_ plan: SubscriptionPlan) {
        recordCall()
        capturedOverrideSubscriptionPlan = plan
    }

    func clearOverrideSubscriptionPlan() {
        recordCall()
    }

    // MARK: URI Cache

    var stubbedURICache: [String: String] = [:]

    var capturedURICacheSet: (originalUri: String, parsedUri: String)?
    func uriCacheSet(originalUri: String, parsedUri: String) {
        recordCall()
        capturedURICacheSet = (originalUri, parsedUri)
    }

    func uriCacheGet(originalUri: String) -> String? {
        recordCall()
        return stubbedURICache[originalUri]
    }
}
