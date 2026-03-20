// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data

@Observable
private class ShaderClock {
    var accumulatedTime: Double = 5
    var speed: Float = 1.5
    var targetSpeed: Float = 0
    private var lastDate: Date = Date()

    func tick(now: Date) {
        let delta = now.timeIntervalSince(lastDate)
        guard delta > 0, delta < 1.0 else {
            lastDate = now
            return
        }
        speed += (targetSpeed - speed) * min(Float(delta) * 2.0, 1.0)
        accumulatedTime += Double(speed) * delta
        lastDate = now
    }
}

@available(iOS 26.0, *)
struct ShareLinkItemView: View {
    
    @State var presenter: ShareLinkItemPresenter
    @Environment(\.dismiss) private var dismiss
    @Namespace var namespace
    
    @State private var clock = ShaderClock()
    @State private var scale: Float = 2.2
    @State private var swirlStrength: Float = 0.18
    @State private var coreBrightness: Float = 0
    @State private var glowAmount: Float = 0
    
    // MARK: - Body

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(maxHeight: 32)
                
                Text("2FAS Share")
                    .font(.title1Emphasized)
                    .zIndex(1)
                
                Spacer(minLength: 0)
                
                iconCard
                
                Spacer(minLength: 0)
                
                ZStack(alignment: .bottom) {
                    configurationControls
                    successSummary
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(alignment: .top) {
            Image(.shareLinkTop)
                .resizable()
                .frame(height: 159)
                .ignoresSafeArea()
//                .scaleEffect(0.5, anchor: .top)
                .scaleEffect(presenter.isUploading ? 0.01 : 1, anchor: .top)
//                .offset(y: -60)
                .animation(.smooth(duration: 0.2), value: presenter.isUploading)

        }
        .background(Color(UIColor(light: .systemGroupedBackground, dark: .black)))
        .tint(.accent)
        .onChange(of: presenter.isUploading) { _, uploading in
            if uploading {
                clock.targetSpeed = 5
            }
        }
        .onChange(of: presenter.isSuccess) { _, uploading in
            if uploading {
                clock.targetSpeed = 2
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
        .sheet(isPresented: $presenter.isPasswordSheetPresented) {
            ShareLinkItemPasswordView(
                presenter: .init(
                    initialPassword: presenter.password,
                    interactor: presenter.interactor
                ),
                onSave: { presenter.onPasswordSaved($0) },
                onCancel: { presenter.onPasswordCancelled() }
            )
        }
        .sheet(isPresented: $presenter.isShareSheetPresented) {
            if let url = presenter.shareURL {
                ShareSheetView(
                    title: presenter.name,
                    url: url,
                    activityComplete: { presenter.isShareSheetPresented = false },
                    activityError: { presenter.isShareSheetPresented = false }
                )
            }
        }
        .sensoryFeedback(.success, trigger: presenter.isSuccess)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }
    
    var isLoading: Bool {
        presenter.isUploading && presenter.isSuccess == false
    }
    
    @ViewBuilder
    var cloud: some View {
        TimelineView(.animation) { timeline in
            let _ = clock.tick(now: timeline.date)
            
            let shader: Shader = ShaderLibrary.bundle(.commonUI).violetCloud(
                .float2(400, 400),
                .float(clock.accumulatedTime),
                .float(1.0),
                .float(scale),
                .float(swirlStrength),
                .float(coreBrightness),
                .float(glowAmount)
            )

            Rectangle()
                .fill(shader)
                .frame(width: 400, height: 400)
                .drawingGroup()
                .scaleEffect(presenter.isSuccess ? 0.85 : 1)
                .blur(radius: 20)
                .opacity(0.5)
        }
    }
    
    // MARK: - Icon Card

    @ViewBuilder
    private var iconCard: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                if presenter.isPaymentCard {
                    CardView(
                        issuer: presenter.cardIssuer,
                        name: presenter.name,
                        cardNumberMask: presenter.cardNumberMask
                    )
                    .scaleEffect(0.65)
                    .frame(width: 260, height: 180)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    
                } else {
                    VStack(spacing: 16) {
                        IconRendererView(content: presenter.iconContent)
                        Text(presenter.name)
                            .font(.title3Emphasized)
                    }
                    .frame(width: 200, height: 180)
                    .glassEffect(.regular, in: .rect(cornerRadius: 40))
                }

                if presenter.isExpanded {
                    HStack(spacing: 40) {
                        Text("Link generated")
                            .font(.title3)
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.success500)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.s)
                    .frame(width: 280)
                    .glassEffect(.regular, in: .rect(cornerRadius: 40))
                }
            }
            .background {
                cloud
                    .scaleEffect(presenter.isUploading ? 1.0 : 0.1)
                    .offset(y: presenter.isSuccess ? -50 : 0)
                    .animation(.smooth, value: presenter.isUploading)
            }
            .frame(maxWidth: .infinity)
        }
        .offset(y: presenter.isSuccess ? 12 : 0)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240)
    }

    // MARK: - Configuration Controls

    @ViewBuilder
    private var configurationControls: some View {
        VStack(spacing: 16) {
            ShareLinkSection {
                HStack(spacing: 16) {
                    Image(systemName: "timer")
                        .frame(width: 24)
                        .foregroundStyle(.primary)
                    Text("Link expiration time")
                    Spacer()
                    Picker("Link expiration time", selection: $presenter.selectedExpiration) {
                        Section {
                            ForEach(LinkExpiration.shortDurations) { expiration in
                                Text(expiration.title).tag(expiration)
                            }
                        }
                        Section {
                            ForEach(LinkExpiration.longDurations) { expiration in
                                Text(expiration.title).tag(expiration)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.base1000)
                }
                .padding(.leading, Spacing.l)
                .padding(.trailing, Spacing.xs)
            }

            ShareLinkSection {
                HStack(spacing: 16) {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .frame(width: 24)
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading) {
                        Text("One time access")
                            .font(.bodyEmphasized)
                        Text("Link will expire after one use")
                            .font(.subheadline)
                    }
                    .layoutPriority(1)

                    Toggle(isOn: $presenter.isOneTimeAccess, label: {})
                }
                .padding(.horizontal, Spacing.l)
            }

            ShareLinkSection {
                Button {
                    presenter.onAccessPasswordTapped()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .frame(width: 24)

                        VStack(alignment: .leading) {
                            Text("Access password")
                                .font(.bodyEmphasized)
                            Text("Add extra security layer.")
                                .font(.subheadline)
                        }
                        Spacer()

                        HStack(spacing: Spacing.s) {
                            Text(presenter.password.isEmpty ? "Off" : "On")
                            
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.itemDetailRowHighlight)
            }

            Button("Continue") {
                presenter.onContinue()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(.vertical)
        }
        .padding(.horizontal)
        .opacity(presenter.isUploading ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: presenter.isUploading)
    }

    // MARK: - Success Summary

    @ViewBuilder
    private var successSummary: some View {
        VStack(alignment: .leading) {
            Text("Share settings")
                .font(.title2Emphasized)
                .padding(.horizontal, Spacing.l)
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xl)

            VStack(spacing: 24) {
                HStack(spacing: 16) {
                    Image(systemName: "timer")
                        .frame(width: 24)
                    Text("Link expiration time")
                    Spacer()
                    Text(presenter.selectedExpiration.title)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.horizontal, Spacing.l)

                if presenter.isOneTimeAccess {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .frame(width: 24)
                        Text("One time access")
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.horizontal, Spacing.l)
                }

                if !presenter.password.isEmpty {
                    HStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .frame(width: 24)
                        Text("Password")
                        Spacer()
                        Button("Copy") {
                            presenter.onCopyPassword()
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.horizontal, Spacing.l)
                }
            }
            .padding(.bottom, Spacing.xll)
            
            Button("Share") {
                presenter.onShare()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding()
        }
        .opacity(presenter.isSuccess ? 1 : 0)
        .blur(radius: presenter.isSuccess ? 0 : 6)
        .animation(.easeInOut(duration: 0.3).delay(0.1), value: presenter.isSuccess)
    }
}

@available(iOS 26.0, *)
#Preview {
    NavigationStack {
        ShareLinkItemView(
            presenter: .init(
                itemID: ItemID(),
                interactor: ShareLinkItemPreviewInteractor()
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(.gray)
    }
}

class ShareLinkItemPreviewInteractor: ShareLinkItemModuleInteracting {
    func fetchItem(for itemID: ItemID) -> ItemData? {
        .paymentCard(PaymentCardItemData(
            id: itemID,
            vaultId: UUID(),
            metadata: .init(
                creationDate: Date(),
                modificationDate: Date(),
                protectionLevel: .topSecret,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: "My Visa Card",
            content: .init(
                name: "My Visa Card",
                cardHolder: "John Doe",
                cardIssuer: PaymentCardIssuer.visa.rawValue,
                cardNumber: nil,
                cardNumberMask: "**** 4242",
                expirationDate: nil,
                securityCode: nil,
                notes: nil
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

    func generatePassword() -> String {
        "Pr3v!ewP@ss"
    }

    var shareLinkConfig: ShareLinkConfig? { nil }
    func saveShareLinkConfig(expirationSeconds: TimeInterval, isOneTimeAccess: Bool) {}
}

@available(iOS 26.0, *)
private struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
