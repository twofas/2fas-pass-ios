// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let noteFont = UIFont.preferredFont(forTextStyle: .body)
    static let minHeightNotes: CGFloat = (noteFont.ascender - noteFont.descender + noteFont.leading) * 12
    static let revealAnimationDuration: TimeInterval = 0.15
    static let expandAnimationDuration: TimeInterval = 0.2
    static let moreGradientWidth: CGFloat = 32
}

struct SecureNoteDetailFormView: View {
    
    let presenter: SecureNoteFormPresenter

    @State
    private var noteHeight: CGFloat = 0
    
    @State
    private var selectedField: SelectedField?
    
    @Namespace
    private var namespace
    
    private enum SelectedField: Hashable {
        case note
    }

    var body: some View {
        ItemDetailFormTitle(name: presenter.name, icon: .contentType(.secureNote))
        noteView
        ItemDetailFormProtectionLevel(presenter.protectionLevel)
        ItemDetailFormNotes(presenter.additionalInfo)
    }
    
    @ViewBuilder
    private var noteView: some View {
        ZStack {
            Color.clear
                .overlay(alignment: .top) {
                    SecureNoteTextView(text: presenter.note ?? "", height: $noteHeight)
                        .linkContextMenu({ url in
                            UIMenu(children: [
                                UIAction(title: T.commonOpen) { [weak presenter] _ in
                                    presenter?.onOpen(url)
                                },
                                UIAction(title: T.commonCopy) { [weak presenter] _ in
                                    presenter?.onCopy(url)
                                }
                            ])
                        })
                        .onTap {
                            selectedField = .note
                        }
                        .frame(height: noteHeight)
                }
                .clipped()
                .opacity(presenter.isReveal ? 1 : 0)
                .animation(.easeInOut(duration: Constants.revealAnimationDuration), value: presenter.isReveal)
                .overlay(alignment: .bottomTrailing, content: {
                    if presenter.isNoteExpanded == false {
                        HStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, Color(.secondarySystemGroupedBackground)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: Constants.moreGradientWidth)
                            
                            Color(.secondarySystemGroupedBackground)
                        }
                        .matchedGeometryEffect(id: "more", in: namespace, isSource: false)
                    }
                })
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        withAnimation(.smooth(duration: Constants.expandAnimationDuration)) {
                            presenter.isNoteExpanded.toggle()
                        }
                    } label: {
                        Text(T.secureNoteTextMoreAction.localizedKey)
                            .padding(.leading, Constants.moreGradientWidth)
                            .padding(.bottom, 1)
                    }
                    .buttonStyle(.borderless)
                    .matchedGeometryEffect(id: "more", in: namespace, isSource: true)
                    .opacity(presenter.isNoteExpanded == false && noteHeight > Constants.minHeightNotes && presenter.isReveal ? 1 : 0)
                    .animation(.easeInOut(duration: Constants.revealAnimationDuration), value: noteHeight > Constants.minHeightNotes)
                    .animation(.easeInOut(duration: Constants.revealAnimationDuration), value: presenter.isReveal)
                }
                .frame(height: presenter.isReveal ? (presenter.isNoteExpanded ? noteHeight : Constants.minHeightNotes) : Constants.minHeightNotes, alignment: .top)
                .frame(maxWidth: .infinity)
            
            if presenter.isReveal == false {
                lockedNoteView
            }
        }
        .sensoryFeedback(.selection, trigger: presenter.isReveal) { _, newValue in
            newValue
        }
        .onChange(of: selectedField == .note) { _, newValue in
            if newValue {
                presenter.onSelectNote()
            }
        }
        .editMenu($selectedField, equals: .note, actions: [
            UIAction(title: T.commonCopy) { _ in
                presenter.onCopyNote()
            }
        ])
    }
    
    private var lockedNoteView: some View {
        LockButton(text: Text(T.secureNoteTextRevealViewAction.localizedKey)) {
            presenter.onViewNote()
        }
        .frame(maxWidth: .infinity, minHeight: Constants.minHeightNotes, alignment: .center)
        .transition(.identity)
    }
}

private struct SecureNoteTextView: UIViewRepresentable {
    
    let text: String
    
    @Binding var height: CGFloat

    private var onTap: Callback?
    private var linkMenu: ((URL) -> UIMenu)?
    
    init(text: String, height: Binding<CGFloat>) {
        self.text = text
        self._height = height
    }
    
    func onTap(_ onTap: @escaping () -> Void) -> Self {
        var instance = self
        instance.onTap = onTap
        return instance
    }
    
    func linkContextMenu(_ menu: @escaping (URL) -> UIMenu) -> Self {
        var instance = self
        instance.linkMenu = menu
        return instance
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.font = Constants.noteFont
        textView.delegate = context.coordinator
        textView.dataDetectorTypes = [.phoneNumber, .link]
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(SecureNoteTextView.Coordinator.handleTapOnTextView(_:)))
        tap.delegate = context.coordinator
        textView.addGestureRecognizer(tap)
        
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        Task { @MainActor in
            let targetSize = CGSize(
                width: uiView.bounds.width,
                height: UIView.layoutFittingExpandedSize.height
            )

            let newSize = uiView.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            if height != newSize.height {
                height = newSize.height
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate, UIEditMenuInteractionDelegate {
        var parent: SecureNoteTextView

        private var linkContextMenuItem: (url: URL, rect: CGRect, interaction: UIEditMenuInteraction)?
        
        init(_ parent: SecureNoteTextView) {
            self.parent = parent
        }

        @objc func handleTapOnTextView(_ gesture: UITapGestureRecognizer) {
            parent.onTap?()
        }
        
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            UIAction { [weak self] _ in
                self?.openContextMenu(from: textView, for: textItem)
            }
        }
        
        private func openContextMenu(from textView: UITextView, for item: UITextItem) {
            guard case .link(let url) = item.content else { return }
            
            guard let textRange = textViewRange(from: item.range, in: textView) else { return }

            let interaction = UIEditMenuInteraction(delegate: self)
            textView.addInteraction(interaction)

            let rect = textView.firstRect(for: textRange)
            linkContextMenuItem = (url, rect, interaction)
                        
            let config = UIEditMenuConfiguration(identifier: UUID(), sourcePoint: .zero)
            config.preferredArrowDirection = .down
            interaction.presentEditMenu(with: config)
        }
        
        private func textViewRange(from nsRange: NSRange, in textView: UITextView) -> UITextRange? {
            guard
                let start = textView.position(from: textView.beginningOfDocument, offset: nsRange.location),
                let end = textView.position(from: start, offset: nsRange.length)
            else { return nil }

            return textView.textRange(from: start, to: end)
        }
        
        private func firstRect(for range: UITextRange, in textView: UITextView) -> CGRect {
            let rects = textView.selectionRects(for: range)
            return rects.first?.rect ?? .zero
        }
        
        // MARK: - UIEditMenuInteractionDelegate
        
        func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let linkContextMenuItem else { return nil }
            return parent.linkMenu?(linkContextMenuItem.url)
        }
        
        func editMenuInteraction(_ interaction: UIEditMenuInteraction, targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
            linkContextMenuItem?.rect ?? .zero
        }
        
        func editMenuInteraction(_ interaction: UIEditMenuInteraction, willDismissMenuFor configuration: UIEditMenuConfiguration, animator: any UIEditMenuInteractionAnimating) {
            linkContextMenuItem = nil
        }
        
        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let textView = gestureRecognizer.view as? UITextView else {
                return true
            }
            
            // Unselect if any text is selected
            
            if textView.selectedTextRange?.isEmpty == false {
                textView.selectedTextRange = nil
                return false
            }
            
            // Hide the link context menu if it is open
            
            if let linkContextMenuItem {
                linkContextMenuItem.interaction.dismissMenu()
                return false
            }

            // Ignore the gesture if the user taps on a link
            
            let location = touch.location(in: textView)
            let locationInTextContainer = CGPoint(
                x: location.x - textView.textContainerInset.left,
                y: location.y - textView.textContainerInset.top
            )

            let characterIndex = textView.layoutManager.characterIndex(
                for: locationInTextContainer,
                in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            if characterIndex < textView.textStorage.length {
                let attributes = textView.textStorage.attributes(at: characterIndex, effectiveRange: nil)
                if attributes[.link] != nil {
                    return false
                }
            }
            
            return true
        }
    }
}
