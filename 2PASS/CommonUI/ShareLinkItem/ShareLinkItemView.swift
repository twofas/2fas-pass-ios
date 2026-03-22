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
    @State private var borderPhase: CGFloat = 0
    @State private var borderProgress: CGFloat = 0
    @State private var spinnerStartDate: Date?
    @State private var showGlow: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var glassAccentColor: Color? {
        colorScheme == .dark ? Color(UIColor(hexString: "#8800FF")!) : nil
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(maxHeight: 16)
                
                Text("2FAS Share")
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
        .background(alignment: .top) {
            Image(.shareLinkTop)
                .resizable()
                .frame(height: 159)
                .ignoresSafeArea()
//                .scaleEffect(0.5, anchor: .top)
                .scaleEffect(presenter.isUploading ? 2 : 2, anchor: .top)
//                .offset(y: -60)
                .animation(.smooth(duration: 0.4), value: presenter.isUploading)
                .opacity(colorScheme == .dark ? 1.0 : 0.6)

        }
        .background(Color(UIColor(light: .systemGroupedBackground, dark: .black)))
        .tint(.accent)
        .onChange(of: presenter.isUploading) { _, uploading in
            if uploading {
                clock.targetSpeed = 5
                spinnerStartDate = Date()
            } else {
                spinnerStartDate = nil
                borderPhase = 0
                borderProgress = 0
            }
        }
        .onChange(of: presenter.isSuccess) { _, success in
            if success {
                clock.targetSpeed = 2
                spinnerStartDate = nil
                showGlow = true
                borderProgress = 0.1
                let spinnerSpeed = 1.0 / 1.3 // matches TimelineView's elapsed / 1.3
                withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: spinnerSpeed)) {
                    borderProgress = 1
                }
                withAnimation(.easeOut(duration: 0.35)) {
                    showGlow = false
                }
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
                ShareLinkSheetView(
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presenter.isSuccess = false
                    presenter.isExpanded = false
                    presenter.isUploading = false
                    borderPhase = 0
                    borderProgress = 0
                    spinnerStartDate = nil
                    showGlow = false
                } label: {
                    Image(systemName: "arrow.counterclockwise")
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

    private func borderFrame(cornerRadius: CGFloat) -> some View {
        let borderColor = Color(UIColor(hexString: "#8800FF")!).opacity(0.8)
        let glowOpacity: CGFloat = showGlow ? 0.5 : 0
        let shape = OffsetRoundedRect(cornerRadius: cornerRadius, startFraction: borderPhase)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(UIColor(hexString: "#8800FF")!), lineWidth: 1)
                .opacity(0.1)

            // Spinner (TimelineView-driven, only while uploading)
            if let spinnerStartDate {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(spinnerStartDate)
                    let phase = (elapsed / 1.3).truncatingRemainder(dividingBy: 1)
                    let _ = { borderPhase = phase }()
                    
                    // Spinner line
                    OffsetRoundedRect(cornerRadius: cornerRadius, startFraction: phase)
                        .trim(from: 0, to: 0.1)
                        .stroke(borderColor, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    
                    // Spinner glow at leading edge
                    OffsetRoundedRect(cornerRadius: cornerRadius, startFraction: phase)
                        .trim(from: 0.08, to: 0.1)
                        .stroke(Color(UIColor(hexString: "BB77FF")!), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .blur(radius: 4)
                        .opacity(0.5)
                }
            }
            
            // Success fill — fixed start, only end moves
            shape
                .trim(from: 0, to: borderProgress)
                .stroke(borderColor, style: StrokeStyle(lineWidth: 1, lineCap: .round))

            // Glow at the leading edge
            shape
                .trim(from: max(borderProgress - 0.02, 0), to: borderProgress)
                .stroke(Color(UIColor(hexString: "BB77FF")!), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .blur(radius: 4)
                .opacity(glowOpacity)
        }
    }

    // MARK: - Icon Card

    @ViewBuilder
    private var iconCard: some View {
//        GlassEffectContainer(spacing: 20) {
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
                    .glassEffect(.regular.tint(glassAccentColor?.opacity(presenter.isSuccess ? 0.08 : 0.00)), in: .rect(cornerRadius: 20))
                    .overlay {
                        borderFrame(cornerRadius: 20)
                    }
                    .scaleEffect(presenter.isUploading && presenter.isSuccess == false ? 0.93 : 1)
                    .animation(.smooth(duration: 0.4), value: presenter.isUploading)
                    
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
                    .glassEffect(.regular.tint(glassAccentColor?.opacity(presenter.isSuccess ? 0.05 : 0.00)), in: .rect(cornerRadius: 40))
                    .overlay {
                        borderFrame(cornerRadius: 40)
                    }
                    .scaleEffect(presenter.isUploading && presenter.isSuccess == false ? 0.93 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: presenter.isUploading)
                }

                if presenter.isExpanded {
                    HStack {
                        Text("Link generated")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.success500)
                    }
                    .padding(.leading, 4)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .frame(width: 260)
                    .glassEffect(.regular, in: .rect(cornerRadius: 40))
                    .transition(
                        .modifier(
                            active: BlurModifier(radius: 8, opacity: 0, scale: 0.8, offsetY: -50),
                            identity: BlurModifier(radius: 0, opacity: 1, scale: 1, offsetY: 0)
                        )
                    )
                }
//            }
//            .background {
//                cloud
//                    .scaleEffect(presenter.isUploading ? 1.0 : 0.1)
//                    .offset(y: presenter.isSuccess ? -50 : 0)
//                    .animation(.smooth, value: presenter.isUploading)
//            }
//            .frame(maxWidth: .infinity)
        }
        .offset(y: presenter.isSuccess ? 30 : 0)
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
                .padding(.bottom, Spacing.s)

            ShareLinkDetailSection {
                HStack(spacing: 16) {
                    Image(systemName: "timer")
                        .frame(width: 24)
                    Text("Link expiration time")
                    Spacer()
                    Text(presenter.selectedExpiration.title)
                }

                if presenter.isOneTimeAccess {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .frame(width: 24)
                        Text("One time access")
                        Spacer()
                        Image(systemName: "checkmark")
                    }
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
        .blur(radius: presenter.isSuccess ? 0 : 8)
        .animation(.easeInOut(duration: 0.3).delay(0.1), value: presenter.isSuccess)
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

/// A rounded rectangle path that starts at an arbitrary position along the perimeter.
/// This allows `trim(from:to:)` to work correctly without wrapping issues.
private struct OffsetRoundedRect: Shape {
    let cornerRadius: CGFloat
    var startFraction: CGFloat

    var animatableData: CGFloat {
        get { startFraction }
        set { startFraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let hEdge = rect.width - 2 * r
        let vEdge = rect.height - 2 * r
        let arcLen = CGFloat.pi / 2 * r

        let segLens = [hEdge, arcLen, vEdge, arcLen, hEdge, arcLen, vEdge, arcLen]
        let total = segLens.reduce(0, +)
        let target = startFraction * total

        // Find which segment the start falls in
        var acc: CGFloat = 0
        var si = 0
        var sf: CGFloat = 0
        for i in 0..<8 {
            if acc + segLens[i] > target {
                si = i
                sf = segLens[i] > 0 ? (target - acc) / segLens[i] : 0
                break
            }
            acc += segLens[i]
        }

        // Arc definitions: center, startAngle, endAngle (radians, clockwise visually)
        let arcs: [(c: CGPoint, s: CGFloat, e: CGFloat)] = [
            (CGPoint(x: rect.maxX - r, y: rect.minY + r), -.pi / 2, 0),
            (CGPoint(x: rect.maxX - r, y: rect.maxY - r), 0, .pi / 2),
            (CGPoint(x: rect.minX + r, y: rect.maxY - r), .pi / 2, .pi),
            (CGPoint(x: rect.minX + r, y: rect.minY + r), .pi, 3 * .pi / 2),
        ]

        var path = Path()
        path.move(to: pointOn(seg: si, frac: sf, rect: rect, r: r))

        // Trace: rest of start segment → 7 full segments → beginning of start segment
        for i in 0...8 {
            let idx = (si + i) % 8
            let from: CGFloat = (i == 0) ? sf : 0
            let to: CGFloat = (i == 8) ? sf : 1
            guard from < to else { continue }

            switch idx {
            case 0:
                path.addLine(to: pointOn(seg: 0, frac: to, rect: rect, r: r))
            case 2:
                path.addLine(to: pointOn(seg: 2, frac: to, rect: rect, r: r))
            case 4:
                path.addLine(to: pointOn(seg: 4, frac: to, rect: rect, r: r))
            case 6:
                path.addLine(to: pointOn(seg: 6, frac: to, rect: rect, r: r))
            case 1, 3, 5, 7:
                let arc = arcs[idx / 2]
                let a0 = arc.s + from * (arc.e - arc.s)
                let a1 = arc.s + to * (arc.e - arc.s)
                path.addArc(center: arc.c, radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
            default:
                break
            }
        }

        return path
    }

    /// Compute a point at `frac` (0...1) along segment `seg` of the rounded rect.
    private func pointOn(seg: Int, frac: CGFloat, rect: CGRect, r: CGFloat) -> CGPoint {
        let hEdge = rect.width - 2 * r
        let vEdge = rect.height - 2 * r
        switch seg % 8 {
        case 0: return CGPoint(x: rect.minX + r + frac * hEdge, y: rect.minY)
        case 1:
            let a = -CGFloat.pi / 2 + frac * CGFloat.pi / 2
            return CGPoint(x: rect.maxX - r + r * cos(a), y: rect.minY + r + r * sin(a))
        case 2: return CGPoint(x: rect.maxX, y: rect.minY + r + frac * vEdge)
        case 3:
            let a = frac * CGFloat.pi / 2
            return CGPoint(x: rect.maxX - r + r * cos(a), y: rect.maxY - r + r * sin(a))
        case 4: return CGPoint(x: rect.maxX - r - frac * hEdge, y: rect.maxY)
        case 5:
            let a = CGFloat.pi / 2 + frac * CGFloat.pi / 2
            return CGPoint(x: rect.minX + r + r * cos(a), y: rect.maxY - r + r * sin(a))
        case 6: return CGPoint(x: rect.minX, y: rect.maxY - r - frac * vEdge)
        case 7:
            let a = CGFloat.pi + frac * CGFloat.pi / 2
            return CGPoint(x: rect.minX + r + r * cos(a), y: rect.minY + r + r * sin(a))
        default: return .zero
        }
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
    }
}

