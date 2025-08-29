// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

private struct Constants {
    static let systemTopItemHeight: CGFloat = 44
    static let searchBarHeight: CGFloat = 56
    static let largeTitleHeight: CGFloat = 52
    
    static let inlineTitleAnimationDuration = 0.2
}

final class ItemsListNavigationBar: UINavigationBar {
    
    enum TitleDisplayMode {
        case large
        case inline
    }
    
    var contentTypePickerOptions: () -> [ItemsContentTypePickerOption] = { [] } {
        didSet {
            inlineContentTypePickerView?.options = contentTypePickerOptions
            largeContentTypePickerView.options = contentTypePickerOptions
        }
    }
    
    var largeDisplayModeHeight: CGFloat {
        Constants.systemTopItemHeight + Constants.largeTitleHeight + Constants.searchBarHeight
    }
    
    var titleDisplayMode: TitleDisplayMode = .large {
        didSet {
            guard oldValue != titleDisplayMode else { return }

            switch titleDisplayMode {
            case .inline:
                if #available(iOS 26.0, *) {
                } else {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    standardAppearance = appearance
                }
            case .large:
                if #available(iOS 26.0, *) {
                } else {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithTransparentBackground()
                    appearance.backgroundColor = Asset.mainBackgroundColor.color
                    standardAppearance = appearance
                }
            }
            
            titleAnimator?.stopAnimation(true)
            titleAnimator = UIViewPropertyAnimator(duration: Constants.inlineTitleAnimationDuration, curve: .easeInOut, animations: {
                for subview in self.topItem?.titleView?.subviews ?? [] {
                    subview.alpha = self.titleDisplayMode == .large ? 0 : 1
                }
            })
            titleAnimator?.addCompletion { position in
                self.titleAnimator = nil
            }
            titleAnimator?.startAnimation()
        }
    }
    
    private var titleAnimator: UIViewPropertyAnimator?
    
    private let supplementaryContainerView = UIView()
    private let largeContentTypePickerView = ItemsContentTypePickerView()
    let searchBar = ItemsListSearchBar()
    
    var selectedContentTypeFilter: ItemContentTypeFilter = .all {
        didSet {
            inlineContentTypePickerView?.selectedContentType = selectedContentTypeFilter
            largeContentTypePickerView.selectedContentType = selectedContentTypeFilter
        }
    }
    
    var onContentTypeFilterChanged: ((ItemContentTypeFilter) -> Void)?
    
    var backgroundInsets: UIEdgeInsets = .zero {
        didSet {
            setNeedsLayout()
        }
    }
    
    private var inlineContentTypePickerView: ItemsContentTypePickerView? {
        topItem?.titleView as? ItemsContentTypePickerView
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        supplementaryContainerView.clipsToBounds = true
        
        supplementaryContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(supplementaryContainerView)
        
        NSLayoutConstraint.activate([
            supplementaryContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            supplementaryContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            supplementaryContainerView.topAnchor.constraint(equalTo: topAnchor, constant: Constants.systemTopItemHeight),
            supplementaryContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        supplementaryContainerView.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: supplementaryContainerView.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: supplementaryContainerView.trailingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: supplementaryContainerView.bottomAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: Constants.searchBarHeight)
        ])
        
        largeContentTypePickerView.translatesAutoresizingMaskIntoConstraints = false
        supplementaryContainerView.addSubview(largeContentTypePickerView)
        NSLayoutConstraint.activate([
            largeContentTypePickerView.leadingAnchor.constraint(equalTo: supplementaryContainerView.leadingAnchor, constant: Spacing.l),
            largeContentTypePickerView.trailingAnchor.constraint(lessThanOrEqualTo: supplementaryContainerView.trailingAnchor, constant: -Spacing.l),
            largeContentTypePickerView.bottomAnchor.constraint(equalTo: searchBar.topAnchor),
            largeContentTypePickerView.heightAnchor.constraint(equalToConstant: Constants.largeTitleHeight)
        ])
        
        largeContentTypePickerView.selectedContentType = selectedContentTypeFilter
        largeContentTypePickerView.onChange = { [weak self] filer in
            self?.inlineContentTypePickerView?.selectedContentType = filer
            self?.onContentTypeFilterChanged?(filer)
        }
    }
    
    override func pushItem(_ item: UINavigationItem, animated: Bool) {
        let pickerView = ItemsContentTypePickerView(sizeMode: .inline)
        pickerView.selectedContentType = selectedContentTypeFilter
        pickerView.onChange = { [weak self] filer in
            self?.largeContentTypePickerView.selectedContentType = filer
            self?.onContentTypeFilterChanged?(filer)
        }
        item.titleView = pickerView
        super.pushItem(item, animated: animated)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        for subview in subviews {
            let className = NSStringFromClass(type(of: subview))

            if className.contains("_UIBarBackground") || className.contains("UIBarBackground") {
                subview.frame = subview.frame.inset(by: backgroundInsets)
            }
        }
    }
}
