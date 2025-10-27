// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ColorAsset.Color", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetColorTypeAlias = ColorAsset.Color
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal static let _1passwordIcon = ImageAsset(name: "1password.icon")
  internal static let _2PASSLogo = ImageAsset(name: "2PASSLogo")
  internal static let _2PASSLogoRecoveryKit = ImageAsset(name: "2PASSLogoRecoveryKit")
  internal static let _2PASSLogoText = ImageAsset(name: "2PASSLogoText")
  internal static let _2PASSShield = ImageAsset(name: "2PASSShield")
  internal static let _2PASSShieldRecoveryKit = ImageAsset(name: "2PASSShieldRecoveryKit")
  internal static let barsBackground = ImageAsset(name: "BarsBackground")
  internal static let accentColor = ColorAsset(name: "AccentColor")
  internal static let backroundSecondary = ColorAsset(name: "BackroundSecondary")
  internal static let descriptionTextColor = ColorAsset(name: "DescriptionTextColor")
  internal static let destructiveActionColor = ColorAsset(name: "DestructiveActionColor")
  internal static let dividerColor = ColorAsset(name: "DividerColor")
  internal static let inactiveColor = ColorAsset(name: "InactiveColor")
  internal static let inactiveControlColor = ColorAsset(name: "InactiveControlColor")
  internal static let labelSecondaryColor = ColorAsset(name: "LabelSecondaryColor")
  internal static let labelTertiaryColor = ColorAsset(name: "LabelTertiaryColor")
  internal static let mainBackgroundColor = ColorAsset(name: "MainBackgroundColor")
  internal static let mainInvertedTextColor = ColorAsset(name: "MainInvertedTextColor")
  internal static let mainTextColor = ColorAsset(name: "MainTextColor")
  internal static let download = ImageAsset(name: "Download")
  internal static let emergencyKit1 = ImageAsset(name: "EmergencyKit1")
  internal static let emergencyKit2 = ImageAsset(name: "EmergencyKit2")
  internal static let emergencyKit3 = ImageAsset(name: "EmergencyKit3")
  internal static let emergencyKit4 = ImageAsset(name: "EmergencyKit4")
  internal static let enableBackup = ImageAsset(name: "EnableBackup")
  internal static let generateSecretKeyBlur = ImageAsset(name: "GenerateSecretKeyBlur")
  internal static let iCloudLogo = ImageAsset(name: "ICloud.logo")
  internal static let intro1 = ImageAsset(name: "Intro1")
  internal static let intro2 = ImageAsset(name: "Intro2")
  internal static let masterKey1 = ImageAsset(name: "MasterKey1")
  internal static let masterKey2 = ImageAsset(name: "MasterKey2")
  internal static let masterKey3 = ImageAsset(name: "MasterKey3")
  internal static let maze = ImageAsset(name: "Maze")
  internal static let onboardingInfo = ImageAsset(name: "OnboardingInfo")
  internal static let shadowLine = ImageAsset(name: "ShadowLine")
  internal static let smallShield = ImageAsset(name: "SmallShield")
  internal static let socialDiscord = ImageAsset(name: "social_discord")
  internal static let socialGithub = ImageAsset(name: "social_github")
  internal static let socialTwitter = ImageAsset(name: "social_twitter")
  internal static let socialYoutube = ImageAsset(name: "social_youtube")
  internal static let applePasswordsIcon = ImageAsset(name: "apple.passwords.icon")
  internal static let bitwardenIcon = ImageAsset(name: "bitwarden.icon")
  internal static let chromeIcon = ImageAsset(name: "chrome.icon")
  internal static let copyActionIcon = ImageAsset(name: "copy.action.icon")
  internal static let copyIcon = ImageAsset(name: "copy.icon")
  internal static let customExclamationmarkShieldFill = ImageAsset(name: "custom.exclamationmark.shield.fill")
  internal static let dashlaneIcon = ImageAsset(name: "dashlane.icon")
  internal static let discordIcon = ImageAsset(name: "discord.icon")
  internal static let enpassIcon = ImageAsset(name: "enpass.icon")
  internal static let facebookIcon = ImageAsset(name: "facebook.icon")
  internal static let firefoxIcon = ImageAsset(name: "firefox.icon")
  internal static let generateIcon = ImageAsset(name: "generate.icon")
  internal static let githubIcon = ImageAsset(name: "github.icon")
  internal static let highlySecretTierFigure = ImageAsset(name: "highly.secret.tier.figure")
  internal static let importItemsIcon = ImageAsset(name: "import.items.icon")
  internal static let keepassIcon = ImageAsset(name: "keepass.icon")
  internal static let keepassxcIcon = ImageAsset(name: "keepassxc.icon")
  internal static let lastpassIcon = ImageAsset(name: "lastpass.icon")
  internal static let linkedinIcon = ImageAsset(name: "linkedin.icon")
  internal static let lockFileHeaderIcon = ImageAsset(name: "lock.file.header.icon")
  internal static let manualInputIcon = ImageAsset(name: "manual.input.icon")
  internal static let microsoftedgeIcon = ImageAsset(name: "microsoftedge.icon")
  internal static let protonIcon = ImageAsset(name: "proton.icon")
  internal static let qrcodeCorner = ImageAsset(name: "qrcode.corner")
  internal static let quickSetupIcon = ImageAsset(name: "quick.setup.icon")
  internal static let quickSetupSmallIcon = ImageAsset(name: "quick.setup.small.icon")
  internal static let redditIcon = ImageAsset(name: "reddit.icon")
  internal static let secretTierFigure = ImageAsset(name: "secret.tier.figure")
  internal static let securityTiersLevelsFigure = ImageAsset(name: "security.tiers.levels.figure")
  internal static let shieldBorder = ImageAsset(name: "shield.border")
  internal static let shieldFill = ImageAsset(name: "shield.fill")
  internal static let shieldLefthalfFilled = ImageAsset(name: "shield.lefthalf.filled")
  internal static let shieldLefthalfFilled2 = ImageAsset(name: "shield.lefthalf.filled2")
  internal static let shieldLefthalfFilled3 = ImageAsset(name: "shield.lefthalf.filled3")
  internal static let shieldLefthalfFilled4 = ImageAsset(name: "shield.lefthalf.filled4")
  internal static let shieldLefthalfFilled5 = ImageAsset(name: "shield.lefthalf.filled5")
  internal static let shieldLefthalfFilled6 = ImageAsset(name: "shield.lefthalf.filled6")
  internal static let tier1Icon = ImageAsset(name: "tier1.icon")
  internal static let tier2Icon = ImageAsset(name: "tier2.icon")
  internal static let tier3Icon = ImageAsset(name: "tier3.icon")
  internal static let tiersHelpHeader = ImageAsset(name: "tiers.help.header")
  internal static let topSecretTierFigure = ImageAsset(name: "top.secret.tier.figure")
  internal static let transferIcon = ImageAsset(name: "transfer.icon")
  internal static let transferItemsIcon = ImageAsset(name: "transfer.items.icon")
  internal static let twoFASAuth = ImageAsset(name: "twoFASAuth")
  internal static let vaultDecryptionKitArrow = ImageAsset(name: "vault.decryption.kit.arrow")
  internal static let vaultDecryptionKitDocumentSeed = ImageAsset(name: "vault.decryption.kit.document.seed")
  internal static let vaultDecryptionKitDocumentSeedMasterkey = ImageAsset(name: "vault.decryption.kit.document.seed.masterkey")
  internal static let vaultDecryptionKitFullDocument = ImageAsset(name: "vault.decryption.kit.full.document")
  internal static let vaultDecryptionKitQrcodeEncryptionHashOff = ImageAsset(name: "vault.decryption.kit.qrcode.encryption.hash.off")
  internal static let vaultDecryptionKitQrcodeEncryptionHashOn = ImageAsset(name: "vault.decryption.kit.qrcode.encryption.hash.on")
  internal static let warningIcon = ImageAsset(name: "warning.icon")
  internal static let xIcon = ImageAsset(name: "x.icon")
  internal static let youtubeIcon = ImageAsset(name: "youtube.icon")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal final class ColorAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  internal private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  #if os(iOS) || os(tvOS)
  @available(iOS 11.0, tvOS 11.0, *)
  internal func color(compatibleWith traitCollection: UITraitCollection) -> Color {
    let bundle = BundleToken.bundle
    guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal private(set) lazy var swiftUIColor: SwiftUI.Color = {
    SwiftUI.Color(asset: self)
  }()
  #endif

  fileprivate init(name: String) {
    self.name = name
  }
}

internal extension ColorAsset.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  convenience init?(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Color {
  init(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }
}
#endif

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  internal func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

internal extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: ImageAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
