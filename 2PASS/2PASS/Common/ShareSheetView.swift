// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ShareSheetView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIActivityViewController
    
    let title: String
    let url: URL
    let activityComplete: Callback
    let activityError: Callback
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: [])
        activity.excludedActivityTypes = [
            .addToHomeScreen,
            .addToReadingList,
            .assignToContact,
            .collaborationCopyLink,
            .collaborationInviteWithLink,
            .copyToPasteboard,
            .markupAsPDF,
            .openInIBooks,
            .postToFacebook,
            .postToVimeo,
            .postToWeibo,
            .postToFlickr,
            .postToTwitter,
            .postToTencentWeibo,
            .sharePlay
        ]
        activity.title = title
        activity.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            if completed {
                activityComplete()
            }
            
            if let error = error {
                Log("There was an error while saving file: \(error)")
                activityError()
            }
        }
        return activity
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
