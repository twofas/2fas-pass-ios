// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

public extension UIFont {
    static var largeTitleEmphasized: UIFont {
        let largeTitleFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        return UIFont.systemFont(ofSize: largeTitleFont.pointSize, weight: .bold)
    }
    
    static var title1Emphasized: UIFont {
        let title1Font = UIFont.preferredFont(forTextStyle: .title1)
        return UIFont.systemFont(ofSize: title1Font.pointSize, weight: .bold)
    }
    
    static var title2Emphasized: UIFont {
        let title2Font = UIFont.preferredFont(forTextStyle: .title2)
        return UIFont.systemFont(ofSize: title2Font.pointSize, weight: .bold)
    }
    
    static var title3Emphasized: UIFont {
        let title3Font = UIFont.preferredFont(forTextStyle: .title3)
        return UIFont.systemFont(ofSize: title3Font.pointSize, weight: .semibold)
    }
    
    static var headlineEmphasized: UIFont {
        let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
        return UIFont.systemFont(ofSize: headlineFont.pointSize, weight: .semibold)
    }
    
    static var bodyEmphasized: UIFont {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        return UIFont.systemFont(ofSize: bodyFont.pointSize, weight: .semibold)
    }
    
    static var calloutEmphasized: UIFont {
        let calloutFont = UIFont.preferredFont(forTextStyle: .callout)
        return UIFont.systemFont(ofSize: calloutFont.pointSize, weight: .semibold)
    }
    
    static var subheadlineEmphasized: UIFont {
        let subheadlineFont = UIFont.preferredFont(forTextStyle: .subheadline)
        return UIFont.systemFont(ofSize: subheadlineFont.pointSize, weight: .semibold)
    }
    
    static var footnoteEmphasized: UIFont {
        let footnoteFont = UIFont.preferredFont(forTextStyle: .footnote)
        return UIFont.systemFont(ofSize: footnoteFont.pointSize, weight: .semibold)
    }
    
    static var caption1Emphasized: UIFont {
        let caption1Font = UIFont.preferredFont(forTextStyle: .caption1)
        return UIFont.systemFont(ofSize: caption1Font.pointSize, weight: .medium)
    }
    
    static var caption2Emphasized: UIFont {
        let caption2Font = UIFont.preferredFont(forTextStyle: .caption2)
        return UIFont.systemFont(ofSize: caption2Font.pointSize, weight: .semibold)
    }
}

public extension Font {
    static var largeTitleEmphasized: Font {
        return .largeTitle.weight(.bold)
    }
    
    static var title1Emphasized: Font {
        return .title.weight(.bold)
    }
    
    static var title2Emphasized: Font {
        return .title2.weight(.bold)
    }
    
    static var title3Emphasized: Font {
        return .title3.weight(.semibold)
    }
    
    static var headlineEmphasized: Font {
        return .headline.weight(.semibold)
    }
    
    static var bodyEmphasized: Font {
        return .body.weight(.semibold)
    }
    
    static var calloutEmphasized: Font {
        return .callout.weight(.semibold)
    }
    
    static var subheadlineEmphasized: Font {
        return .subheadline.weight(.semibold)
    }
    
    static var footnoteEmphasized: Font {
        return .footnote.weight(.semibold)
    }
    
    static var caption1Emphasized: Font {
        return .caption.weight(.medium)
    }
    
    static var caption2Emphasized: Font {
        return .caption.weight(.semibold)
    }
}
