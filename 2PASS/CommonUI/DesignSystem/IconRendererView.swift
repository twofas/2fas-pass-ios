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
    case icon(UIImage, ignoreCornerRadius: Bool = false)
    case label(String, color: UIColor?)
    case placeholder
    case contentType(ItemContentType)
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
            case .icon(let icon, let ignoreCornerRadius):
                IconView(icon: icon)
                    .ignoreCornerRadius(ignoreCornerRadius)
            case .contentType(let contentType):
                ContentTypeIconView(contentType: contentType)
            case .label(let title, let color):
                loginLabelView(title: title, color: color)
            case .placeholder:
                RoundedRectangle(cornerRadius: Constants.iconCornerRadius)
                    .foregroundStyle(.inactiveControl)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.inactive)
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
    
    private func loginLabelView(title: String, color: UIColor?) -> some View {
        Color(color ?? ItemContentType.login.secondaryColor)
            .overlay {
                Text(verbatim: title)
                    .fontWeight(.bold)
                    .font(.body)
                    .foregroundStyle(textColor(forLabelColor: color))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
    }
    
    private func textColor(forLabelColor color: UIColor?) -> Color {
        if let color {
            return color.isDark ? .white : .black
        } else {
            return Color(ItemContentType.login.primaryColor)
        }
    }
}

#Preview {
    IconRendererView(content: .loading)
    IconRendererView(content: .label("AB", color: nil))
    IconRendererView(content: .label("AB", color: .red))
    IconRendererView(content: .icon(UIImage(named: "2PASSShield")!))
    IconRendererView(content: .contentType(.secureNote))
}

private struct IconView: View {
    
    let icon: UIImage
    
    private var ignoreCornerRadius = false
    
    init(icon: UIImage) {
        self.icon = icon
    }
    
    var body: some View {
        ZStack {
            IconBackgroundBlurView(icon: icon)

            let image = Image(uiImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: Constants.innerIconSize, height: Constants.innerIconSize)
            
            if ignoreCornerRadius {
                image
            } else {
                image
                    .clipShape(RoundedRectangle(cornerRadius: Constants.innerIconCornerRadius))
            }
        }
    }
    
    func ignoreCornerRadius(_ ignore: Bool) -> Self {
        var instance = self
        instance.ignoreCornerRadius = ignore
        return instance
    }
}

private struct ContentTypeIconView: View {
    
    let contentType: ItemContentType
    
    var body: some View {
        ZStack {
            Color(uiColor: contentType.secondaryColor)
            
            if let icon = contentType.icon {
                Image(uiImage: icon)
                    .frame(width: Constants.innerIconSize, height: Constants.innerIconSize)
                    .foregroundStyle(Color(contentType.primaryColor))
            }
        }
    }
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
