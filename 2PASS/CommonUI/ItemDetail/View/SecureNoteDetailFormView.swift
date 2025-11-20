// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

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
    private var isNoteExpanded = false
    
    @Namespace
    private var namespace
    
    var body: some View {
        ItemDetalFormTitle(name: presenter.name, icon: .contentType(.secureNote))
        noteView
        ItemDetailFormProtectionLevel(presenter.protectionLevel)
        ItemDetailFormTags(presenter.tags)
    }
    
    @ViewBuilder
    private var noteView: some View {
        ZStack {
        Color.clear
            .overlay(alignment: .top) {
                SecureNoteTextView(text: presenter.note ?? "", height: $noteHeight)
                    .frame(height: noteHeight)
            }
            .clipped()
            .opacity(presenter.isReveal ? 1 : 0)
            .animation(.easeInOut(duration: Constants.revealAnimationDuration), value: presenter.isReveal)
            .overlay(alignment: .bottomTrailing, content: {
                if isNoteExpanded == false {
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
                        isNoteExpanded.toggle()
                    }
                } label: {
                    Text("more")
                        .padding(.leading, Constants.moreGradientWidth)
                        .padding(.bottom, 1)
                }
                .buttonStyle(.borderless)
                .matchedGeometryEffect(id: "more", in: namespace, isSource: true)
                .opacity(isNoteExpanded == false && noteHeight > Constants.minHeightNotes && presenter.isReveal ? 1 : 0)
                .animation(.easeInOut(duration: Constants.revealAnimationDuration), value: noteHeight > Constants.minHeightNotes)
                .animation(.easeInOut(duration: Constants.revealAnimationDuration), value: presenter.isReveal)
            }
            .frame(height: presenter.isReveal ? (isNoteExpanded ? noteHeight : Constants.minHeightNotes) : Constants.minHeightNotes, alignment: .top)
            .frame(maxWidth: .infinity)
        
            if presenter.isReveal == false {
                lockedNoteView
            }
        }
    }
    
    private var lockedNoteView: some View {
        Button {
            presenter.onViewNote()
        } label: {
            VStack(spacing: Spacing.m) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.neutral200)
                
                Text("Tap to view")
            }
        }
        .contentShape(Rectangle())
        .padding(.bottom, Spacing.xs)
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, minHeight: Constants.minHeightNotes, alignment: .center)
        .transition(.identity)
    }
}

private struct SecureNoteTextView: UIViewRepresentable {
    
    let text: String
    @Binding var height: CGFloat

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

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SecureNoteTextView

        init(_ parent: SecureNoteTextView) {
            self.parent = parent
        }
    }
}
