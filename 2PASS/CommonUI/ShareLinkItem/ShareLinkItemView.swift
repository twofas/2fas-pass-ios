// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data

struct ShareLinkItemView: View {
    
    @State var presenter: ShareLinkItemPresenter
    @Environment(\.dismiss) private var dismiss

    @Environment(\.colorScheme) private var colorScheme

    @State private var iconCardHeight: CGFloat?
    @State private var iconCardSize: CGSize?
    @State private var frozenIconCardHeight: CGFloat?
    @State private var frozenIconCardSize: CGSize?
    
    private enum Constants {
        // Layout
        static let backgroundImageScale: CGFloat = 2
        static let cardSize = CGSize(width: 250, height: 170)
        static let cardMinWidth: CGFloat = 200
        static let paymentCardCornerRadius: CGFloat = 20
        static let iconCardCornerRadius: CGFloat = 40
        static let linkBadgeWidth: CGFloat = 260
        static let iconFrameWidth: CGFloat = 24
        static let fullSizeCardExtra: CGFloat = 70
        static let linkOffset: CGFloat = 35

        // Scale
        static let paymentCardScale: CGFloat = 0.65
        static let uploadingScale: CGFloat = 0.93

        // Opacity
        static let lightModeBackgroundOpacity: CGFloat = 0.6
        static let paymentGlassTintOpacity: CGFloat = 0.08
        static let iconGlassTintOpacity: CGFloat = 0.05

        // Animation
        static let transitionDuration: CGFloat = 0.3
        static let successAnimationDelay: CGFloat = 0.1
        static let springResponse: CGFloat = 0.4
        static let springDamping: CGFloat = 0.7
        static let smoothDuration: CGFloat = 0.4

        // Blur transition
        static let blurRadius: CGFloat = 8
        static let blurBadgeScale: CGFloat = 0.8
        static let blurBadgeOffsetY: CGFloat = -50
    }

    private static let accentViolet = Color(UIColor(hexString: "#8800FF")!)

    private var glassAccentColor: Color? {
        colorScheme == .dark ? Self.accentViolet : nil
    }

    private var uploadState: ShareLinkUploadState {
        presenter.uploadState
    }

    private var borderPhase: ShareLinkProgressBorder.Phase {
        if uploadState.isUploading { .loading }
        else if uploadState.isSuccess { .success }
        else { .idle }
    }

    // MARK: - Body

    var body: some View {
        content
            .background(alignment: .top) {
                Image(.shareLinkTop)
                    .scaleEffect(Constants.backgroundImageScale, anchor: .top)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 1.0 : Constants.lightModeBackgroundOpacity)
            }
            .background(Color(UIColor(light: .systemGroupedBackground, dark: .black)))
            .tint(.accent)
            .onAppear {
                presenter.onAppear()
            }
            .onDisappear {
                presenter.onDisappear()
            }
            .router(router: ShareLinkItemRouter(), destination: $presenter.destination)
            .sensoryFeedback(.success, trigger: uploadState.isSuccess)
            .sensoryFeedback(.error, trigger: uploadState.isFailure)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        dismiss()
                    }
                }
            }
            .introspect(.viewController, on: .iOS(.v17, .v18, .v26)) { viewControler in
                viewControler.traitOverrides.userInterfaceLevel = .base
            }
    }

    private var content: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(maxHeight: Spacing.xs)

                Text(.shareLinkItemTitle)
                    .font(.title1Emphasized)
                    .zIndex(1)

                Spacer(minLength: 0)

                iconCard
                    .padding(.horizontal, Spacing.l)

                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    if case .idle = presenter.uploadState {
                        configurationControls
                            .transition(
                                .modifier(
                                    active: BlurModifier(radius: Constants.blurRadius, opacity: 0),
                                    identity: BlurModifier(radius: 0, opacity: 1)
                                )
                            )
                    }
                }
                .animation(.easeInOut(duration: Constants.transitionDuration), value: uploadState.isUploading)
                .fixedSize(horizontal: false, vertical: true)

                if presenter.uploadState.isUploading || presenter.uploadState.isSuccess {
                    successSummary
                        .opacity(uploadState.isSuccess ? 1 : 0)
                        .animation(
                            .easeInOut(duration: Constants.transitionDuration)
                                .delay(Constants.successAnimationDelay),
                            value: uploadState.isSuccess
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    // MARK: - Icon Card

    @ViewBuilder
    private var iconCard: some View {
        GeometryReader { proxy in
            VStack(spacing: Spacing.l) {
                Group {
                    if presenter.isPaymentCard {
                        CardView(
                            issuer: presenter.cardIssuer,
                            name: presenter.name,
                            cardNumberMask: presenter.cardNumberMask
                        )
                        .scaleEffect(Constants.paymentCardScale)
                        .offset(y: Spacing.xxs)
                        .frame(width: Constants.cardSize.width, height: Constants.cardSize.height)
                        .cardGlassEffect(
                            cornerRadius: Constants.paymentCardCornerRadius,
                            tint: glassAccentColor?.opacity(uploadState.isSuccess ? Constants.paymentGlassTintOpacity : 0.00)
                        )
                        .overlay {
                            ShareLinkProgressBorder(
                                cornerRadius: Constants.paymentCardCornerRadius,
                                phase: borderPhase
                            )
                        }
                        
                    } else {
                        VStack(spacing: Spacing.l) {
                            IconRendererView(content: presenter.iconContent)
                            Text(presenter.name)
                                .font(.title3Emphasized)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, Spacing.xll)
                        .offset(y: Spacing.xxs)
                        .frame(minWidth: Constants.cardMinWidth, maxHeight: Constants.cardSize.height)
                        .cardGlassEffect(
                            cornerRadius: Constants.iconCardCornerRadius,
                            tint: glassAccentColor?.opacity(uploadState.isSuccess ? Constants.iconGlassTintOpacity : 0.00)
                        )
                        .overlay {
                            ShareLinkProgressBorder(
                                cornerRadius: Constants.iconCardCornerRadius,
                                phase: borderPhase
                            )
                        }
                    }
                }
                .scaleEffect(uploadState.isUploading ? Constants.uploadingScale : 1)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    if frozenIconCardHeight == nil {
                        iconCardHeight = height
                    }
                }
                .frame(height: frozenIconCardHeight)
                .animation(
                    .spring(response: Constants.springResponse, dampingFraction: Constants.springDamping),
                    value: uploadState.isUploading
                )
                
                if uploadState.isSuccess, proxy.size.height > fullSizeCard {
                    HStack {
                        Text(.shareLinkItemLinkGenerated)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.success500)
                    }
                    .padding(.leading, Spacing.xs)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .frame(width: Constants.linkBadgeWidth)
                    .cardGlassEffect(cornerRadius: Constants.iconCardCornerRadius)
                    .transition(
                        .modifier(
                            active: BlurModifier(
                                radius: Constants.blurRadius,
                                opacity: 0,
                                scale: Constants.blurBadgeScale,
                                offsetY: Constants.blurBadgeOffsetY
                            ),
                            identity: BlurModifier(radius: 0, opacity: 1, scale: 1, offsetY: 0)
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.s)
            .position(
                cordPosition(in: proxy)
            )
            .animation(.smooth(duration: Constants.smoothDuration), value: uploadState.isSuccess)
            .onAppear {
                iconCardSize = proxy.size
            }
            .onChange(of: proxy.size) { _, newSize in
                if frozenIconCardSize == nil {
                    iconCardSize = newSize
                }
            }
        }
    }
    
    private var fullSizeCard: CGFloat {
        (iconCardHeight ?? 0) + Spacing.xl + Constants.fullSizeCardExtra
    }
    
    private func cordPosition(in proxy: GeometryProxy) -> CGPoint {
        guard let frozenSize = frozenIconCardSize else {
            return CGPoint(
                x: proxy.size.width / 2,
                y: proxy.size.height / 2
            )
        }

        let center = CGPoint(x: frozenSize.width / 2, y: frozenSize.height / 2)
        let fullSize = fullSizeCard
        let isLinkGenerated = proxy.size.height > fullSize
        let linkOffset = Constants.linkOffset

        if frozenSize.height > fullSize {
            return CGPoint(
                x: center.x,
                y: center.y + (presenter.uploadState.isSuccess && isLinkGenerated ? linkOffset : 0)
            )
        } else {
            return CGPoint(
                x: center.x,
                y: proxy.size.height / 2 - (!presenter.uploadState.isSuccess && isLinkGenerated ? linkOffset : 0)
            )
        }
    }

    private func rowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .frame(width: Constants.iconFrameWidth)
    }

    // MARK: - Configuration Controls

    @ViewBuilder
    private var configurationControls: some View {
        VStack(spacing: Spacing.m) {
            GroupedSection {
                HStack(spacing: Spacing.l) {
                    rowIcon("timer")
                        .foregroundStyle(.primary)
                    Text(.shareLinkItemExpirationTime)
                    Spacer()
                    Picker(String(localized: .shareLinkItemExpirationTime), selection: $presenter.selectedExpiration) {
                        Section {
                            ForEach(presenter.shortDurations, id: \.self) { expiration in
                                Text(expiration.duration, format: presenter.expirationFormat)
                                    .tag(expiration)
                            }
                        }
                        Section {
                            ForEach(presenter.longDurations, id: \.self) { expiration in
                                Text(expiration.duration, format: presenter.expirationFormat)
                                    .tag(expiration)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.base1000)
                }
                .groupedRowInsets(EdgeInsets(
                    top: Spacing.l,
                    leading: Spacing.l,
                    bottom: Spacing.l,
                    trailing: Spacing.xs
                ))
            }

            GroupedSection {
                HStack(spacing: Spacing.l) {
                    rowIcon("arrow.trianglehead.2.clockwise")
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading) {
                        Text(.shareLinkItemOneTimeAccess)
                            .font(.bodyEmphasized)
                        Text(.shareLinkItemOneTimeAccessDescription)
                            .font(.subheadline)
                    }
                    .layoutPriority(1)

                    Toggle(isOn: $presenter.isOneTimeAccess, label: {})
                }
            }

            GroupedSection {
                Button {
                    presenter.onAccessPasswordTapped()
                } label: {
                    HStack(spacing: Spacing.l) {
                        rowIcon("lock.fill")

                        VStack(alignment: .leading) {
                            Text(.shareLinkItemAccessPassword)
                                .font(.bodyEmphasized)
                            Text(.shareLinkItemAccessPasswordDescription)
                                .font(.subheadline)
                        }
                        
                        Spacer()

                        HStack(spacing: Spacing.s) {
                            Text(presenter.password.isEmpty ? .commonOff : .commonOn)

                            Image(systemName: "chevron.right")
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.groupedRowHighlight)
            }

            Button(.commonContinue) {
                frozenIconCardHeight = iconCardHeight
                frozenIconCardSize = iconCardSize
                
                presenter.onContinue()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(Spacing.l)
        }
    }

    // MARK: - Success Summary

    @ViewBuilder
    private var successSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(.shareLinkItemShareSettings)
                .font(.title2Emphasized)
                .padding(.horizontal, Spacing.xll3)
                .padding(.bottom, Spacing.xxs)

            GroupedSection {
                HStack(spacing: Spacing.l) {
                    rowIcon("timer")
                    Text(.shareLinkItemExpirationTime)
                    Spacer()
                    Text(presenter.selectedExpiration.duration, format: presenter.expirationFormat)
                }

                if presenter.isOneTimeAccess {
                    HStack(spacing: Spacing.l) {
                        rowIcon("arrow.trianglehead.2.clockwise")
                        Text(.shareLinkItemOneTimeAccess)
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }

                if !presenter.password.isEmpty {
                    HStack(spacing: Spacing.l) {
                        rowIcon("lock.fill")
                        Text(.commonPassword)
                        Spacer()
                        Button(.commonCopy) {
                            presenter.onCopyPassword()
                        }
                    }
                }
            }
            .padding(.bottom, Spacing.s)
            
            Button(.commonShare) {
                presenter.onShare()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(Spacing.l)
        }
    }
}

private extension View {
    @ViewBuilder
    func cardGlassEffect(cornerRadius: CGFloat, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

private struct BlurModifier: ViewModifier {
    let radius: CGFloat
    let opacity: CGFloat
    let scale: CGFloat
    let offsetY: CGFloat
    
    init(radius: CGFloat, opacity: CGFloat, scale: CGFloat = 1, offsetY: CGFloat = 0) {
        self.radius = radius
        self.opacity = opacity
        self.scale = scale
        self.offsetY = offsetY
    }

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: offsetY)
    }
}

class ShareLinkItemPreviewInteractor: ShareLinkItemModuleInteracting {
    func fetchItem(for itemID: ItemID) -> ItemData? {
        .login(LoginItemData(
            id: itemID,
            vaultId: UUID(),
            metadata: .init(
                creationDate: Date(),
                modificationDate: Date(),
                protectionLevel: .topSecret,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: "GitHub",
            content: .init(
                name: "GitHub",
                username: "john@example.com",
                password: nil,
                notes: nil,
                iconType: .domainIcon("github.com"),
                uris: [.init(uri: "https://github.com", match: .domain)]
            )
        ))
    }

    func fetchIconImage(from url: URL) async throws -> Data {
        Data()
    }

    func shareItem(id: ItemID, password: String?, validForSeconds: Int, singleUse: Bool) async throws -> URL {
        try await Task.sleep(for: .milliseconds(2500))
        return URL(string: "https://share.2fas.com/#/preview-id/v1k/preview-nonce/preview-key")!
    }

    var shareLinkConfig: ShareLinkConfig? { nil }
    func saveShareLinkConfig(expirationSeconds: TimeInterval, isOneTimeAccess: Bool) {}
    func copyToClipboard(_ str: String, isSecure: Bool) {}
}

#Preview {
    NavigationStack {
        ShareLinkItemView(
            presenter: .init(
                itemID: ItemID(),
                interactor: ShareLinkItemPreviewInteractor()
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

