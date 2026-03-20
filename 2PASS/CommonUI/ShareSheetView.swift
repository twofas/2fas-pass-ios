// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct ShareSheetView: UIViewControllerRepresentable {
    public typealias UIViewControllerType = UIActivityViewController

    public let title: String
    public let url: URL
    public let activityComplete: Callback
    public let activityError: Callback

    public init(title: String, url: URL, activityComplete: @escaping Callback, activityError: @escaping Callback) {
        self.title = title
        self.url = url
        self.activityComplete = activityComplete
        self.activityError = activityError
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
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

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
