// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let iconSize: CGFloat = 60
    static let iconCornerRadius: CGFloat = 12
    static let smallIconSize: CGFloat = 42
    static let smallIconCornerRadius: CGFloat = 10
    static let innerIconSize: CGFloat = 28
    static let innerIconCornerRadius: CGFloat = 6
}

public enum IconContent {
    case loading
    case icon(UIImage)
    case label(String, color: UIColor?)
    case placeholder
}

extension IconContent {
    
    var isPlaceholder: Bool {
        switch self {
        case .placeholder:
            return true
        default:
            return false
        }
    }
}

public struct IconRendererView: View {
    
    let content: IconContent?
    
    @Environment(\.controlSize) private var controlSize
    
    public init(content: IconContent?) {
        self.content = content
    }
    
    public var body: some View {
        ZStack {
            switch content {
            case .loading:
                ProgressView()
            case .icon(let icon):
                IconView(icon: icon)
            case .label(let title, let color):
                labelView(title: title, color: color)
            case .placeholder:
                RoundedRectangle(cornerRadius: Constants.iconCornerRadius)
                    .foregroundStyle(Asset.inactiveControlColor.swiftUIColor)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(Asset.inactiveColor.swiftUIColor)
                    }
            case nil:
                EmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .frame(width: size, height: size)
    }
    
    private var size: CGFloat {
        switch controlSize {
        case .small, .mini: Constants.smallIconSize
        default: Constants.iconSize
        }
    }
    
    private var cornerRadius: CGFloat {
        switch controlSize {
        case .small, .mini: Constants.smallIconCornerRadius
        default: Constants.iconCornerRadius
        }
    }
    
    private func labelView(title: String, color: UIColor?) -> some View {
        Group {
            if let color {
                Color(color)
            } else {
                IconGradientView_SwiftUI()
            }
        }
        .overlay {
            Text(verbatim: title)
                .font(.bodyEmphasized)
                .fontWeight(.bold)
                .foregroundStyle(textColor(forLabelColor: color))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(Spacing.s)
        }
    }
    
    private func textColor(forLabelColor color: UIColor?) -> Color {
        if let color {
            return color.isDark ? .white : .black
        } else {
            return .brand500
        }
    }
}

#Preview {
    IconRendererView(content: .loading)
    IconRendererView(content: .label("AB", color: nil))
    IconRendererView(content: .label("AB", color: .red))
    IconRendererView(content: .icon(UIImage(named: "2PASSShield")!))
}

private struct IconView: View {
    
    let icon: UIImage
    
    var body: some View {
        ZStack {
            IconBackgroundBlurView(icon: icon)
            
            Image(uiImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.innerIconSize, height: Constants.innerIconSize)
                .clipShape(RoundedRectangle(cornerRadius: Constants.innerIconCornerRadius))
        }
    }
}

private struct IconGradientView_SwiftUI: UIViewRepresentable {
    
    func makeUIView(context: Context) -> IconGradientView {
        IconGradientView()
    }
    
    func updateUIView(_ uiView: IconGradientView, context: Context) {}
}

private struct IconBackgroundBlurView: UIViewRepresentable {
    
    let icon: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView(image: icon)
        imageView.contentMode = .scaleAspectFit
        
        let blurEffect = UIBlurEffect(style: .prominent)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.addSubview(blurView)
        
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = icon
    }
}
