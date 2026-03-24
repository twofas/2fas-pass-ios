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

    private static let accentViolet = Color(UIColor(hexString: "#8800FF")!)

    private var glassAccentColor: Color? {
        colorScheme == .dark ? Self.accentViolet : nil
    }

    private var uploadState: ShareLinkUploadState {
        presenter.uploadState
    }

    // MARK: - Body

    var body: some View {
        content
            .background(alignment: .top) {
                Image(.shareLinkTop)
                    .resizable()
                    .frame(height: 159)
                    .scaleEffect(2, anchor: .top)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 1.0 : 0.6)
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
//                ToolbarItem(placement: .primaryAction) {
//                    Button {
//                        presenter.uploadState = .idle
//                    } label: {
//                        Image(systemName: "arrow.counterclockwise")
//                    }
//                }
            }
            .introspect(.viewController, on: .iOS(.v17, .v18, .v26)) { viewControler in
                viewControler.traitOverrides.userInterfaceLevel = .base
            }
    }

    private var content: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(maxHeight: 16)

                Text(.shareLinkItemTitle)
                    .font(.title1Emphasized)
                    .zIndex(1)

                Spacer(minLength: 0)

                iconCard
                    .padding(.horizontal)

                Spacer(minLength: 0)

                ZStack(alignment: .bottom) {
                    configurationControls
                    successSummary
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - Icon Card

    @ViewBuilder
    private var iconCard: some View {
        VStack(spacing: 20) {
            if presenter.isPaymentCard {
                CardView(
                    issuer: presenter.cardIssuer,
                    name: presenter.name,
                    cardNumberMask: presenter.cardNumberMask
                )
                .scaleEffect(0.65)
                .offset(y: 2)
                .frame(width: 260, height: 180)
                .cardGlassEffect(cornerRadius: 20, tint: glassAccentColor?.opacity(uploadState.isSuccess ? 0.08 : 0.00))
                .overlay {
                    ShareLinkProgressBorder(
                        cornerRadius: 20,
                        uploadState: uploadState
                    )
                }
                .scaleEffect(uploadState.isUploading ? 0.93 : 1)
                .animation(.smooth(duration: 0.4), value: uploadState.isUploading)

            } else {
                VStack(spacing: 16) {
                    IconRendererView(content: presenter.iconContent)
                    Text(presenter.name)
                        .font(.title3Emphasized)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .offset(y: 2)
                .frame(minWidth: 200)
                .frame(height: 180)
                .cardGlassEffect(cornerRadius: 40, tint: glassAccentColor?.opacity(uploadState.isSuccess ? 0.05 : 0.00))
                .overlay {
                    ShareLinkProgressBorder(
                        cornerRadius: 40,
                        uploadState: uploadState
                    )
                }
                .scaleEffect(uploadState.isUploading ? 0.93 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: uploadState.isUploading)
            }
            
            if uploadState.isSuccess {
                HStack {
                    Text(.shareLinkItemLinkGenerated)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.success500)
                }
                .padding(.leading, 4)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
                .frame(width: 260)
                .cardGlassEffect(cornerRadius: 40)
                .transition(
                    .modifier(
                        active: BlurModifier(radius: 8, opacity: 0, scale: 0.8, offsetY: -50),
                        identity: BlurModifier(radius: 0, opacity: 1, scale: 1, offsetY: 0)
                    )
                )
            }
        }
        .offset(y: uploadState.isSuccess ? 30 : 0)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240)
    }

    // MARK: - Configuration Controls

    @ViewBuilder
    private var configurationControls: some View {
        VStack(spacing: 16) {
            GroupedSection {
                HStack(spacing: 16) {
                    Image(systemName: "timer")
                        .frame(width: 24)
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
                HStack(spacing: 16) {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .frame(width: 24)
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
                    HStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .frame(width: 24)

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
                presenter.onContinue()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(.vertical)
            .padding(.horizontal)
        }
        .opacity(uploadState.isUploading || uploadState.isSuccess ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: uploadState.isUploading)
    }

    // MARK: - Success Summary

    @ViewBuilder
    private var successSummary: some View {
        VStack(alignment: .leading) {
            Text(.shareLinkItemShareSettings)
                .font(.title2Emphasized)
                .padding(.horizontal, Spacing.xll3)
                .padding(.bottom, Spacing.s)

            GroupedSection {
                HStack(spacing: 16) {
                    Image(systemName: "timer")
                        .frame(width: 24)
                    Text(.shareLinkItemExpirationTime)
                    Spacer()
                    Text(presenter.selectedExpiration.duration, format: presenter.expirationFormat)
                }

                if presenter.isOneTimeAccess {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .frame(width: 24)
                        Text(.shareLinkItemOneTimeAccess)
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }

                if !presenter.password.isEmpty {
                    HStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .frame(width: 24)
                        Text(.commonPassword)
                        Spacer()
                        Button(.commonCopy) {
                            presenter.onCopyPassword()
                        }
                    }
                }
            }
            .padding(.bottom, Spacing.xll)
            
            Button(.commonShare) {
                presenter.onShare()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding()
        }
        .opacity(uploadState.isSuccess ? 1 : 0)
        .blur(radius: uploadState.isSuccess ? 0 : 8)
        .animation(.easeInOut(duration: 0.3).delay(0.1), value: uploadState.isSuccess)
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
    func copyToClipboard(_ str: String) {}
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

