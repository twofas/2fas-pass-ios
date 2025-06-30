// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

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
  internal static let shieldBorder = ImageAsset(name: "shield.border")
  internal static let shieldFill = ImageAsset(name: "shield.fill")
  internal static let shieldLefthalfFilled = ImageAsset(name: "shield.lefthalf.filled")
  internal static let shieldLefthalfFilled2 = ImageAsset(name: "shield.lefthalf.filled2")
  internal static let shieldLefthalfFilled3 = ImageAsset(name: "shield.lefthalf.filled3")
  internal static let shieldLefthalfFilled4 = ImageAsset(name: "shield.lefthalf.filled4")
  internal static let shieldLefthalfFilled5 = ImageAsset(name: "shield.lefthalf.filled5")
  internal static let shieldLefthalfFilled6 = ImageAsset(name: "shield.lefthalf.filled6")
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
