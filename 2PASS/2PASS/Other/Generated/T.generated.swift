// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum T {
  /// Application couldn’t import your 2FAS Pass Items. Please try again.
  internal static let backupImportingFailureDescription = T.tr("Localizable", " backup_importing_failure_description", fallback: "Application couldn’t import your 2FAS Pass Items. Please try again.")
  /// Can't initialize camera in Split View mode. Open app in full screen and try again.
  internal static let cameraErrorSplitMode = T.tr("Localizable", " camera_error_split_mode", fallback: "Can't initialize camera in Split View mode. Open app in full screen and try again.")
  /// The camera is unavailable because of system overload. Try rebooting the device.
  internal static let cameraErrorSystemOverload = T.tr("Localizable", " camera_error_system_overload", fallback: "The camera is unavailable because of system overload. Try rebooting the device.")
  /// Customize icon
  internal static let customizeIcon = T.tr("Localizable", " customize_icon", fallback: "Customize icon")
  /// You have reached your %d Item limit. Upgrade your plan for unlimited Items.
  internal static func paywallNoticeItemsLimitImportMsg(_ p1: Int) -> String {
    return T.tr("Localizable", " paywall_notice_items_limit_import_msg", p1, fallback: "You have reached your %d Item limit. Upgrade your plan for unlimited Items.")
  }
  /// Restoring these Items would exceed the %d Item limit. Upgrade your plan for unlimited Items.
  internal static func paywallNoticeItemsLimitRestoreMsg(_ p1: Int) -> String {
    return T.tr("Localizable", " paywall_notice_items_limit_restore_msg", p1, fallback: "Restoring these Items would exceed the %d Item limit. Upgrade your plan for unlimited Items.")
  }
  /// You have reached your %d Item limit. Upgrade your plan for unlimited Items.
  internal static func paywallNoticeItemsLimitTransferMsg(_ p1: Int) -> String {
    return T.tr("Localizable", " paywall_notice_items_limit_transfer_msg", p1, fallback: "You have reached your %d Item limit. Upgrade your plan for unlimited Items.")
  }
  /// 3. Multi-Layer Encryption
  internal static let securityTiersHelpLayersSectionTitle = T.tr("Localizable", " security_tiers_help_layers_section_title", fallback: "3. Multi-Layer Encryption")
  /// Your data is protected with a unique, randomly generated SEED combined with your Master Password.
  /// On your device, the SEED is securely stored in Apple's Secure Enclave, so you only need your Master Password to access your data.
  internal static let securityTiersHelpTiersLayersE2eeSubtitle = T.tr("Localizable", " security_tiers_help_tiers_layers_e2ee_subtitle", fallback: "Your data is protected with a unique, randomly generated SEED combined with your Master Password.\nOn your device, the SEED is securely stored in Apple's Secure Enclave, so you only need your Master Password to access your data.")
  /// End-to-End Encryption (E2EE)
  internal static let securityTiersHelpTiersLayersE2eeTitle = T.tr("Localizable", " security_tiers_help_tiers_layers_e2ee_title", fallback: "End-to-End Encryption (E2EE)")
  /// Top Secret
  internal static let securityTiersHelpTiersTopSecretTitle = T.tr("Localizable", " security_tiers_help_tiers_top_secret_title", fallback: "Top Secret")
  /// There was a merge error. Try switching Sync on and off or Restore from iCloud
  internal static let syncErrorIcloudMergeError = T.tr("Localizable", " sync_error_icloud_merge_error", fallback: "There was a merge error. Try switching Sync on and off or Restore from iCloud")
  /// To sync with multiple devices you need to upgrade to Premium plan
  internal static let syncErrorIcloudSyncNotAllowedDescription = T.tr("Localizable", " sync_error_icloud_sync_not_allowed_description", fallback: "To sync with multiple devices you need to upgrade to Premium plan")
  /// Can't enable sync
  internal static let syncErrorIcloudSyncNotAllowedTitle = T.tr("Localizable", " sync_error_icloud_sync_not_allowed_title", fallback: "Can't enable sync")
  /// Incorrect directory URL!
  internal static let syncStatusErrorWrongDirectoryUrl = T.tr("Localizable", " sync_status_error_wrong_directory_url", fallback: "Incorrect directory URL!")
  /// Help 2FAS Pass identify and resolve application problems by submitting anonymous crash reports (application restart required).
  internal static let aboutCrashReportsDescription = T.tr("Localizable", "about_crash_reports_description", fallback: "Help 2FAS Pass identify and resolve application problems by submitting anonymous crash reports (application restart required).")
  /// Discord
  internal static let aboutDiscord = T.tr("Localizable", "about_discord", fallback: "Discord")
  /// Facebook
  internal static let aboutFacebook = T.tr("Localizable", "about_facebook", fallback: "Facebook")
  /// GitHub
  internal static let aboutGithub = T.tr("Localizable", "about_github", fallback: "GitHub")
  /// Invite friends to use 2FAS Pass
  internal static let aboutInviteFriends = T.tr("Localizable", "about_invite_friends", fallback: "Invite friends to use 2FAS Pass")
  /// Check out this awesome password manager app from 2FAS: http://2fas.com/pass/download
  internal static let aboutInviteFriendsShareText = T.tr("Localizable", "about_invite_friends_share_text", fallback: "Check out this awesome password manager app from 2FAS: http://2fas.com/pass/download")
  /// Acknowledgments
  internal static let aboutLibrariesWeUse = T.tr("Localizable", "about_libraries_we_use", fallback: "Acknowledgments")
  /// LinkedIn
  internal static let aboutLinkedin = T.tr("Localizable", "about_linkedin", fallback: "LinkedIn")
  /// Open source licenses
  internal static let aboutOpenSourceLicenses = T.tr("Localizable", "about_open_source_licenses", fallback: "Open source licenses")
  /// Privacy Policy
  internal static let aboutPrivacyPolicy = T.tr("Localizable", "about_privacy_policy", fallback: "Privacy Policy")
  /// Rate us on Play Store
  internal static let aboutRateUs = T.tr("Localizable", "about_rate_us", fallback: "Rate us on Play Store")
  /// Rate us on the App Store
  internal static let aboutRateUsAppStore = T.tr("Localizable", "about_rate_us_app_store", fallback: "Rate us on the App Store")
  /// Reddit
  internal static let aboutReddit = T.tr("Localizable", "about_reddit", fallback: "Reddit")
  /// Connect
  internal static let aboutSectionConnect = T.tr("Localizable", "about_section_connect", fallback: "Connect")
  /// Crash Reporting
  internal static let aboutSectionCrashReporting = T.tr("Localizable", "about_section_crash_reporting", fallback: "Crash Reporting")
  /// General
  internal static let aboutSectionGeneral = T.tr("Localizable", "about_section_general", fallback: "General")
  /// Share
  internal static let aboutSectionShare = T.tr("Localizable", "about_section_share", fallback: "Share")
  /// Send anonymous crash reports
  internal static let aboutSendCrashReports = T.tr("Localizable", "about_send_crash_reports", fallback: "Send anonymous crash reports")
  /// Send logs
  internal static let aboutSendLogsCta = T.tr("Localizable", "about_send_logs_cta", fallback: "Send logs")
  /// About 2FAS Pass
  internal static let aboutTagline = T.tr("Localizable", "about_tagline", fallback: "About 2FAS Pass")
  /// Terms of Use
  internal static let aboutTermsOfUse = T.tr("Localizable", "about_terms_of_use", fallback: "Terms of Use")
  /// Version: **%@**
  internal static func aboutVersionIos(_ p1: Any) -> String {
    return T.tr("Localizable", "about_version_ios %@", String(describing: p1), fallback: "Version: **%@**")
  }
  /// Version:
  internal static let aboutVersionPrefix = T.tr("Localizable", "about_version_prefix", fallback: "Version:")
  /// X
  internal static let aboutX = T.tr("Localizable", "about_x", fallback: "X")
  /// YouTube
  internal static let aboutYoutube = T.tr("Localizable", "about_youtube", fallback: "YouTube")
  /// 2FAS Pass
  internal static let appName = T.tr("Localizable", "app_name", fallback: "2FAS Pass")
  /// Biometrics are disabled due to changes in system fingerprint settings. Use your Master Password to re-enable biometrics in settings.
  internal static let authBiometricsDisabledMessage = T.tr("Localizable", "auth_biometrics_disabled_message", fallback: "Biometrics are disabled due to changes in system fingerprint settings. Use your Master Password to re-enable biometrics in settings.")
  /// Biometrics
  internal static let authBiometricsModalTitle = T.tr("Localizable", "auth_biometrics_modal_title", fallback: "Biometrics")
  /// Unlock
  internal static let authPreviewCta = T.tr("Localizable", "auth_preview_cta", fallback: "Unlock")
  /// Enter your Master Password to unlock the app
  internal static let authPreviewDescription = T.tr("Localizable", "auth_preview_description", fallback: "Enter your Master Password to unlock the app")
  /// Unlock App
  internal static let authPreviewTitle = T.tr("Localizable", "auth_preview_title", fallback: "Unlock App")
  /// Use Biometrics
  internal static let authUseBiometrics = T.tr("Localizable", "auth_use_biometrics", fallback: "Use Biometrics")
  /// Do you want to autofill 
  internal static let autofillLoginDialogBodyPrefix = T.tr("Localizable", "autofill_login_dialog_body_prefix", fallback: "Do you want to autofill ")
  /// Item information for this app or website?
  internal static let autofillLoginDialogBodySuffix = T.tr("Localizable", "autofill_login_dialog_body_suffix", fallback: "Item information for this app or website?")
  /// Fill once
  internal static let autofillLoginDialogNeutral = T.tr("Localizable", "autofill_login_dialog_neutral", fallback: "Fill once")
  /// Fill and remember
  internal static let autofillLoginDialogPositive = T.tr("Localizable", "autofill_login_dialog_positive", fallback: "Fill and remember")
  /// Autofill
  internal static let autofillLoginDialogTitle = T.tr("Localizable", "autofill_login_dialog_title", fallback: "Autofill")
  /// Go to the app for Vault setup.
  internal static let autofillNoVaultMessage = T.tr("Localizable", "autofill_no_vault_message", fallback: "Go to the app for Vault setup.")
  /// Authenticate
  internal static let autofillPromptCta = T.tr("Localizable", "autofill_prompt_cta", fallback: "Authenticate")
  /// Authentication is required to decrypt the Item password for the autofill request
  internal static let autofillPromptDescription = T.tr("Localizable", "autofill_prompt_description", fallback: "Authentication is required to decrypt the Item password for the autofill request")
  /// Autofill Request
  internal static let autofillPromptTitle = T.tr("Localizable", "autofill_prompt_title", fallback: "Autofill Request")
  /// Export
  internal static let backupExportCta = T.tr("Localizable", "backup_export_cta", fallback: "Export")
  /// Application couldn’t export your 2FAS Pass Items. Please try again.
  internal static let backupExportFailedDescription = T.tr("Localizable", "backup_export_failed_description", fallback: "Application couldn’t export your 2FAS Pass Items. Please try again.")
  /// Export failed
  internal static let backupExportFailedTitle = T.tr("Localizable", "backup_export_failed_title", fallback: "Export failed")
  /// Use Export to back up your Items offline.
  internal static let backupExportFooter = T.tr("Localizable", "backup_export_footer", fallback: "Use Export to back up your Items offline.")
  /// Export 2FAS Pass Items
  internal static let backupExportHeader = T.tr("Localizable", "backup_export_header", fallback: "Export 2FAS Pass Items")
  /// Export
  internal static let backupExportSaveCta = T.tr("Localizable", "backup_export_save_cta", fallback: "Export")
  /// Your 2FAS Pass Items will be encrypted with your Master Password and Secret Words for added security.
  internal static let backupExportSaveEncryptToggleDescription = T.tr("Localizable", "backup_export_save_encrypt_toggle_description", fallback: "Your 2FAS Pass Items will be encrypted with your Master Password and Secret Words for added security.")
  /// Encrypt Items
  internal static let backupExportSaveEncryptToggleTitle = T.tr("Localizable", "backup_export_save_encrypt_toggle_title", fallback: "Encrypt Items")
  /// Export your 2FAS Pass Items
  internal static let backupExportSaveSubtitle = T.tr("Localizable", "backup_export_save_subtitle", fallback: "Export your 2FAS Pass Items")
  /// Export Items
  internal static let backupExportSaveTitle = T.tr("Localizable", "backup_export_save_title", fallback: "Export Items")
  /// Your 2FAS Pass Items have been successfully exported to file.
  internal static let backupExportSuccessDescription = T.tr("Localizable", "backup_export_success_description", fallback: "Your 2FAS Pass Items have been successfully exported to file.")
  /// Exported successfully
  internal static let backupExportSuccessTitle = T.tr("Localizable", "backup_export_success_title", fallback: "Exported successfully")
  /// Import
  internal static let backupImportCta = T.tr("Localizable", "backup_import_cta", fallback: "Import")
  /// Import your 2FAS Pass Items to increase (not replace) the number of Items stored in the application.
  internal static let backupImportFooter = T.tr("Localizable", "backup_import_footer", fallback: "Import your 2FAS Pass Items to increase (not replace) the number of Items stored in the application.")
  /// Import 2FAS Pass Items
  internal static let backupImportHeader = T.tr("Localizable", "backup_import_header", fallback: "Import 2FAS Pass Items")
  /// Import failed
  internal static let backupImportingFailureTitle = T.tr("Localizable", "backup_importing_failure_title", fallback: "Import failed")
  /// Importing file...
  internal static let backupImportingFileText = T.tr("Localizable", "backup_importing_file_text", fallback: "Importing file...")
  /// Your 2FAS Pass Items have been successfully imported to the Vault.
  internal static let backupImportingSuccessDescription = T.tr("Localizable", "backup_importing_success_description", fallback: "Your 2FAS Pass Items have been successfully imported to the Vault.")
  /// Imported successfully
  internal static let backupImportingSuccessTitle = T.tr("Localizable", "backup_importing_success_title", fallback: "Imported successfully")
  /// Biometrics Error
  internal static let biometricsErrorDialogTitle = T.tr("Localizable", "biometrics_error_dialog_title", fallback: "Biometrics Error")
  /// Too many failed attempts. Try again later.
  internal static let biometricsModalErrorTooManyAttempts = T.tr("Localizable", "biometrics_modal_error_too_many_attempts", fallback: "Too many failed attempts. Try again later.")
  /// Enable biometrics login
  internal static let biometricsModalSubtitleEnable = T.tr("Localizable", "biometrics_modal_subtitle_enable", fallback: "Enable biometrics login")
  /// Biometrics
  internal static let biometricsModalTitle = T.tr("Localizable", "biometrics_modal_title", fallback: "Biometrics")
  /// Verify Master Password
  internal static let biometryReason = T.tr("Localizable", "biometry_reason", fallback: "Verify Master Password")
  /// Connect
  internal static let bottomBarConnect = T.tr("Localizable", "bottom_bar_connect", fallback: "Connect")
  /// Items
  internal static let bottomBarPasswords = T.tr("Localizable", "bottom_bar_passwords", fallback: "Items")
  /// Settings
  internal static let bottomBarSettings = T.tr("Localizable", "bottom_bar_settings", fallback: "Settings")
  /// Can't initialize the camera. Try rebooting the device.
  internal static let cameraErrorGeneral = T.tr("Localizable", "camera_error_general", fallback: "Can't initialize the camera. Try rebooting the device.")
  /// Another app uses the camera. If closing other apps don't help, then reboot the device.
  internal static let cameraErrorOtherAppUsesCamera = T.tr("Localizable", "camera_error_other_app_uses_camera", fallback: "Another app uses the camera. If closing other apps don't help, then reboot the device.")
  /// Error while scanning QR Code
  internal static let cameraQrCodeError = T.tr("Localizable", "camera_qr_code_error", fallback: "Error while scanning QR Code")
  /// Are you sure you want to delete this backup? You cannot restore it later.
  internal static let cloudVaultDeleteConfirmBody = T.tr("Localizable", "cloud_vault_delete_confirm_body", fallback: "Are you sure you want to delete this backup? You cannot restore it later.")
  /// Delete backup?
  internal static let cloudVaultDeleteConfirmTitle = T.tr("Localizable", "cloud_vault_delete_confirm_title", fallback: "Delete backup?")
  /// Vault deletion failed
  internal static let cloudVaultRemovingFailure = T.tr("Localizable", "cloud_vault_removing_failure", fallback: "Vault deletion failed")
  /// Add
  internal static let commonAdd = T.tr("Localizable", "common_add", fallback: "Add")
  /// Cancel
  internal static let commonCancel = T.tr("Localizable", "common_cancel", fallback: "Cancel")
  /// Close
  internal static let commonClose = T.tr("Localizable", "common_close", fallback: "Close")
  /// Confirm
  internal static let commonConfirm = T.tr("Localizable", "common_confirm", fallback: "Confirm")
  /// Continue
  internal static let commonContinue = T.tr("Localizable", "common_continue", fallback: "Continue")
  /// Copied
  internal static let commonCopied = T.tr("Localizable", "common_copied", fallback: "Copied")
  /// Copy
  internal static let commonCopy = T.tr("Localizable", "common_copy", fallback: "Copy")
  /// Created:
  internal static let commonCreated = T.tr("Localizable", "common_created", fallback: "Created:")
  /// Decrypting
  internal static let commonDecrypting = T.tr("Localizable", "common_decrypting", fallback: "Decrypting")
  /// Delete
  internal static let commonDelete = T.tr("Localizable", "common_delete", fallback: "Delete")
  /// Disabled
  internal static let commonDisabled = T.tr("Localizable", "common_disabled", fallback: "Disabled")
  /// Done
  internal static let commonDone = T.tr("Localizable", "common_done", fallback: "Done")
  /// Edit
  internal static let commonEdit = T.tr("Localizable", "common_edit", fallback: "Edit")
  /// Enabled
  internal static let commonEnabled = T.tr("Localizable", "common_enabled", fallback: "Enabled")
  /// Error
  internal static let commonError = T.tr("Localizable", "common_error", fallback: "Error")
  /// There was an error. Please try again
  internal static let commonGeneralErrorTryAgain = T.tr("Localizable", "common_general_error_try_again", fallback: "There was an error. Please try again")
  /// Help
  internal static let commonHelp = T.tr("Localizable", "common_help", fallback: "Help")
  /// Modified:
  internal static let commonModified = T.tr("Localizable", "common_modified", fallback: "Modified:")
  /// No
  internal static let commonNo = T.tr("Localizable", "common_no", fallback: "No")
  /// Off
  internal static let commonOff = T.tr("Localizable", "common_off", fallback: "Off")
  /// OK
  internal static let commonOk = T.tr("Localizable", "common_ok", fallback: "OK")
  /// On
  internal static let commonOn = T.tr("Localizable", "common_on", fallback: "On")
  /// Open System Settings
  internal static let commonOpenSystemSettings = T.tr("Localizable", "common_open_system_settings", fallback: "Open System Settings")
  /// Other
  internal static let commonOther = T.tr("Localizable", "common_other", fallback: "Other")
  /// Passwords
  internal static let commonPasswords = T.tr("Localizable", "common_passwords", fallback: "Passwords")
  /// Save
  internal static let commonSave = T.tr("Localizable", "common_save", fallback: "Save")
  /// Search
  internal static let commonSearch = T.tr("Localizable", "common_search", fallback: "Search")
  /// Settings
  internal static let commonSettings = T.tr("Localizable", "common_settings", fallback: "Settings")
  /// Suggested
  internal static let commonSuggested = T.tr("Localizable", "common_suggested", fallback: "Suggested")
  /// Try again
  internal static let commonTryAgain = T.tr("Localizable", "common_try_again", fallback: "Try again")
  /// Yes
  internal static let commonYes = T.tr("Localizable", "common_yes", fallback: "Yes")
  /// You are connecting to a new browser extension. Do you want to confirm?
  internal static let connectConfirmMessage = T.tr("Localizable", "connect_confirm_message", fallback: "You are connecting to a new browser extension. Do you want to confirm?")
  /// Confirm
  internal static let connectConfirmTitle = T.tr("Localizable", "connect_confirm_title", fallback: "Confirm")
  /// Connecting….
  internal static let connectConnectionConnecting = T.tr("Localizable", "connect_connection_connecting", fallback: "Connecting….")
  /// Scan again
  internal static let connectConnectionFailedCta = T.tr("Localizable", "connect_connection_failed_cta", fallback: "Scan again")
  /// Please try to scan it again.
  internal static let connectConnectionFailedDescription = T.tr("Localizable", "connect_connection_failed_description", fallback: "Please try to scan it again.")
  /// Connection error
  internal static let connectConnectionFailedTitle = T.tr("Localizable", "connect_connection_failed_title", fallback: "Connection error")
  /// Connected with Browser Extension
  internal static let connectConnectionHeader = T.tr("Localizable", "connect_connection_header", fallback: "Connected with Browser Extension")
  /// Yes, proceed
  internal static let connectConnectionSecurityCheckAcceptCta = T.tr("Localizable", "connect_connection_security_check_accept_cta", fallback: "Yes, proceed")
  /// Are you connecting to the web browser on the computer you trust?
  internal static let connectConnectionSecurityCheckDescription = T.tr("Localizable", "connect_connection_security_check_description", fallback: "Are you connecting to the web browser on the computer you trust?")
  /// Security check
  internal static let connectConnectionSecurityCheckTitle = T.tr("Localizable", "connect_connection_security_check_title", fallback: "Security check")
  /// 2FAS Pass Browser Extension connected to %@.
  internal static func connectConnectionSuccessDescription(_ p1: Any) -> String {
    return T.tr("Localizable", "connect_connection_success_description %@", String(describing: p1), fallback: "2FAS Pass Browser Extension connected to %@.")
  }
  /// Connected
  internal static let connectConnectionSuccessTitle = T.tr("Localizable", "connect_connection_success_title", fallback: "Connected")
  /// Pair the app with a browser extension (**Chrome, Safari, Firefox, Opera**) to securely autofill your Item details while browsing on your desktop.
  internal static let connectIntroDescription = T.tr("Localizable", "connect_intro_description", fallback: "Pair the app with a browser extension (**Chrome, Safari, Firefox, Opera**) to securely autofill your Item details while browsing on your desktop.")
  /// Connect 2FAS Pass to the browser extension
  internal static let connectIntroHeader = T.tr("Localizable", "connect_intro_header", fallback: "Connect 2FAS Pass to the browser extension")
  /// Learn more
  internal static let connectIntroLearnMoreCta = T.tr("Localizable", "connect_intro_learn_more_cta", fallback: "Learn more")
  /// Signature could not be verified.
  internal static let connectInvalidSignatureMessage = T.tr("Localizable", "connect_invalid_signature_message", fallback: "Signature could not be verified.")
  /// Error
  internal static let connectInvalidSignatureTitle = T.tr("Localizable", "connect_invalid_signature_title", fallback: "Error")
  /// Upgrade plan
  internal static let connectModalErrorExtensionsLimitCta = T.tr("Localizable", "connect_modal_error_extensions_limit_cta", fallback: "Upgrade plan")
  /// You’ve reached the limit of connected browsers. Disconnect one to continue, or consider upgrading your plan for more flexibility.
  internal static let connectModalErrorExtensionsLimitSubtitle = T.tr("Localizable", "connect_modal_error_extensions_limit_subtitle", fallback: "You’ve reached the limit of connected browsers. Disconnect one to continue, or consider upgrading your plan for more flexibility.")
  /// Limit reached
  internal static let connectModalErrorExtensionsLimitTitle = T.tr("Localizable", "connect_modal_error_extensions_limit_title", fallback: "Limit reached")
  /// Try again
  internal static let connectModalErrorGenericCta = T.tr("Localizable", "connect_modal_error_generic_cta", fallback: "Try again")
  /// Something went wrong while connecting. Please try again.
  internal static let connectModalErrorGenericSubtitle = T.tr("Localizable", "connect_modal_error_generic_subtitle", fallback: "Something went wrong while connecting. Please try again.")
  /// Error occurred
  internal static let connectModalErrorGenericTitle = T.tr("Localizable", "connect_modal_error_generic_title", fallback: "Error occurred")
  /// Connecting with Browser Extension
  internal static let connectModalHeaderTitle = T.tr("Localizable", "connect_modal_header_title", fallback: "Connecting with Browser Extension")
  /// Connecting…
  internal static let connectModalLoading = T.tr("Localizable", "connect_modal_loading", fallback: "Connecting…")
  /// Close
  internal static let connectModalSuccessCta = T.tr("Localizable", "connect_modal_success_cta", fallback: "Close")
  /// 2FAS Pass Browser Extension connected to %@.
  internal static func connectModalSuccessSubtitle(_ p1: Any) -> String {
    return T.tr("Localizable", "connect_modal_success_subtitle", String(describing: p1), fallback: "2FAS Pass Browser Extension connected to %@.")
  }
  /// Connected
  internal static let connectModalSuccessTitle = T.tr("Localizable", "connect_modal_success_title", fallback: "Connected")
  /// Connected successfully!
  internal static let connectModalSuccessToast = T.tr("Localizable", "connect_modal_success_toast", fallback: "Connected successfully!")
  /// Cancel
  internal static let connectModalUnknownBrowserCtaNegative = T.tr("Localizable", "connect_modal_unknown_browser_cta_negative", fallback: "Cancel")
  /// Yes, proceed
  internal static let connectModalUnknownBrowserCtaPositive = T.tr("Localizable", "connect_modal_unknown_browser_cta_positive", fallback: "Yes, proceed")
  /// Are you connecting to the web browser on the computer you trust?
  internal static let connectModalUnknownBrowserSubtitle = T.tr("Localizable", "connect_modal_unknown_browser_subtitle", fallback: "Are you connecting to the web browser on the computer you trust?")
  /// Security check
  internal static let connectModalUnknownBrowserTitle = T.tr("Localizable", "connect_modal_unknown_browser_title", fallback: "Security check")
  /// Point your camera at the QR code shown by the 2FAS Pass Browser Extension.
  internal static let connectQrInstruction = T.tr("Localizable", "connect_qr_instruction", fallback: "Point your camera at the QR code shown by the 2FAS Pass Browser Extension.")
  /// Open the 2FAS Pass Browser Extension and point your camera at the QR code.
  internal static let connectQrcodeCameraDescription = T.tr("Localizable", "connect_qrcode_camera_description", fallback: "Open the 2FAS Pass Browser Extension and point your camera at the QR code.")
  /// Allow camera access
  internal static let connectSetupCameraCta = T.tr("Localizable", "connect_setup_camera_cta", fallback: "Allow camera access")
  /// For the browser extension to work properly, you must allow the app to use the camera 
  internal static let connectSetupCameraError = T.tr("Localizable", "connect_setup_camera_error", fallback: "For the browser extension to work properly, you must allow the app to use the camera ")
  /// Allow the app to use the camera to connect it with the browser extension by scanning the QR code.
  internal static let connectSetupCameraStepDescription = T.tr("Localizable", "connect_setup_camera_step_description", fallback: "Allow the app to use the camera to connect it with the browser extension by scanning the QR code.")
  /// Camera access
  internal static let connectSetupCameraStepTitle = T.tr("Localizable", "connect_setup_camera_step_title", fallback: "Camera access")
  /// For the browser extension to work properly, please allow 2FAS Pass to use the camera and turn on notifications.
  internal static let connectSetupDescription = T.tr("Localizable", "connect_setup_description", fallback: "For the browser extension to work properly, please allow 2FAS Pass to use the camera and turn on notifications.")
  /// Done
  internal static let connectSetupFinishCta = T.tr("Localizable", "connect_setup_finish_cta", fallback: "Done")
  /// 2FAS Pass Browser Extension
  internal static let connectSetupHeader = T.tr("Localizable", "connect_setup_header", fallback: "2FAS Pass Browser Extension")
  /// Allow notifications
  internal static let connectSetupPushCta = T.tr("Localizable", "connect_setup_push_cta", fallback: "Allow notifications")
  /// Enable notifications to receive the confirmation requests from the browser extension.
  internal static let connectSetupPushStepDescription = T.tr("Localizable", "connect_setup_push_step_description", fallback: "Enable notifications to receive the confirmation requests from the browser extension.")
  /// Push notifications
  internal static let connectSetupPushStepTitle = T.tr("Localizable", "connect_setup_push_step_title", fallback: "Push notifications")
  /// Using push notifications makes communicating with the browser extension much more convenient. Go to **[System Settings](%@)**.
  internal static func connectSetupPushWarningIos(_ p1: Any) -> String {
    return T.tr("Localizable", "connect_setup_push_warning_ios %@", String(describing: p1), fallback: "Using push notifications makes communicating with the browser extension much more convenient. Go to **[System Settings](%@)**.")
  }
  /// 2FAS Pass Browser Extension setup
  internal static let connectSetupStepsHeader = T.tr("Localizable", "connect_setup_steps_header", fallback: "2FAS Pass Browser Extension setup")
  /// Connect
  internal static let connectTitle = T.tr("Localizable", "connect_title", fallback: "Connect")
  /// Custom
  internal static let customizeIconCustom = T.tr("Localizable", "customize_icon_custom", fallback: "Custom")
  /// Favicon URL
  internal static let customizeIconCustomHeader = T.tr("Localizable", "customize_icon_custom_header", fallback: "Favicon URL")
  /// Add URL
  internal static let customizeIconCustomPlaceholder = T.tr("Localizable", "customize_icon_custom_placeholder", fallback: "Add URL")
  /// Icon style
  internal static let customizeIconHeader = T.tr("Localizable", "customize_icon_header", fallback: "Icon style")
  /// Icon
  internal static let customizeIconIcon = T.tr("Localizable", "customize_icon_icon", fallback: "Icon")
  /// Color
  internal static let customizeIconLabelColor = T.tr("Localizable", "customize_icon_label_color", fallback: "Color")
  /// Settings
  internal static let customizeIconLabelHeader = T.tr("Localizable", "customize_icon_label_header", fallback: "Settings")
  /// Label
  internal static let customizeIconLabelKey = T.tr("Localizable", "customize_icon_label_key", fallback: "Label")
  /// Enter label
  internal static let customizeIconLabelPlaceholder = T.tr("Localizable", "customize_icon_label_placeholder", fallback: "Enter label")
  /// Reset
  internal static let customizeIconLabelReset = T.tr("Localizable", "customize_icon_label_reset", fallback: "Reset")
  /// Save Recovery Kit in a safe place
  internal static let decryptionKeyShareSheetTitle = T.tr("Localizable", "decryption_key_share_sheet_title", fallback: "Save Recovery Kit in a safe place")
  /// Just double-checking: Have you securely saved your decryption kit? It's your lifeline to your Vault if you ever need to recover it.
  internal static let decryptionKitConfirmDescription = T.tr("Localizable", "decryption_kit_confirm_description", fallback: "Just double-checking: Have you securely saved your decryption kit? It's your lifeline to your Vault if you ever need to recover it.")
  /// Decryption Kit saved?
  internal static let decryptionKitConfirmTitle = T.tr("Localizable", "decryption_kit_confirm_title", fallback: "Decryption Kit saved?")
  /// Save PDF file
  internal static let decryptionKitCta = T.tr("Localizable", "decryption_kit_cta", fallback: "Save PDF file")
  /// The only way to recover your Vault.
  internal static let decryptionKitDescription = T.tr("Localizable", "decryption_kit_description", fallback: "The only way to recover your Vault.")
  /// If I lose this file, I will lose access to all of my 2FAS Pass data.
  internal static let decryptionKitNoticeMsg = T.tr("Localizable", "decryption_kit_notice_msg", fallback: "If I lose this file, I will lose access to all of my 2FAS Pass data.")
  /// I understand that
  internal static let decryptionKitNoticeTitle = T.tr("Localizable", "decryption_kit_notice_title", fallback: "I understand that")
  /// Share
  internal static let decryptionKitSaveModalCta1 = T.tr("Localizable", "decryption_kit_save_modal_cta1", fallback: "Share")
  /// Save to file
  internal static let decryptionKitSaveModalCta2 = T.tr("Localizable", "decryption_kit_save_modal_cta2", fallback: "Save to file")
  /// Keep your Decryption Kit in a secure place. Never share it with anyone to protect your data.
  internal static let decryptionKitSaveModalDescription = T.tr("Localizable", "decryption_kit_save_modal_description", fallback: "Keep your Decryption Kit in a secure place. Never share it with anyone to protect your data.")
  /// Save Decryption Kit
  internal static let decryptionKitSaveModalTitle = T.tr("Localizable", "decryption_kit_save_modal_title", fallback: "Save Decryption Kit")
  /// Decryption Kit saved!
  internal static let decryptionKitSaveToast = T.tr("Localizable", "decryption_kit_save_toast", fallback: "Decryption Kit saved!")
  /// Done
  internal static let decryptionKitSettingsCta = T.tr("Localizable", "decryption_kit_settings_cta", fallback: "Done")
  /// The file contains the QR code that allows you to recover access to your 2FAS Pass Vault.
  internal static let decryptionKitSettingsDescription = T.tr("Localizable", "decryption_kit_settings_description", fallback: "The file contains the QR code that allows you to recover access to your 2FAS Pass Vault.")
  /// Master Password hash
  internal static let decryptionKitSettingsMasterKey = T.tr("Localizable", "decryption_kit_settings_master_key", fallback: "Master Password hash")
  /// Your QR code consists of:
  internal static let decryptionKitSettingsQrLabel = T.tr("Localizable", "decryption_kit_settings_qr_label", fallback: "Your QR code consists of:")
  /// Secret Words (15-word phrase),
  internal static let decryptionKitSettingsSecretWords = T.tr("Localizable", "decryption_kit_settings_secret_words", fallback: "Secret Words (15-word phrase),")
  /// **Secret Words** (15-word phrase),
  internal static let decryptionKitSettingsSecretWordsIos = T.tr("Localizable", "decryption_kit_settings_secret_words_ios", fallback: "**Secret Words** (15-word phrase),")
  /// Decryption Kit Settings
  internal static let decryptionKitSettingsTitle = T.tr("Localizable", "decryption_kit_settings_title", fallback: "Decryption Kit Settings")
  /// to avoid entering the Master Password to recover my Vault.
  internal static let decryptionKitSettingsToggleMsg = T.tr("Localizable", "decryption_kit_settings_toggle_msg", fallback: "to avoid entering the Master Password to recover my Vault.")
  /// Include the Master Password hash 
  internal static let decryptionKitSettingsToggleTitle = T.tr("Localizable", "decryption_kit_settings_toggle_title", fallback: "Include the Master Password hash ")
  /// Download this PDF
  internal static let decryptionKitStep1 = T.tr("Localizable", "decryption_kit_step1", fallback: "Download this PDF")
  /// Print it and keep it safe
  internal static let decryptionKitStep2 = T.tr("Localizable", "decryption_kit_step2", fallback: "Print it and keep it safe")
  /// Vault Decryption Kit
  internal static let decryptionKitTitle = T.tr("Localizable", "decryption_kit_title", fallback: "Vault Decryption Kit")
  /// Authentication is required to change the Master Password.
  internal static let enterCurrentPasswordDescription = T.tr("Localizable", "enter_current_password_description", fallback: "Authentication is required to change the Master Password.")
  /// Current Password
  internal static let enterCurrentPasswordTitle = T.tr("Localizable", "enter_current_password_title", fallback: "Current Password")
  /// Your backup will be encrypted with your Master Password and Secret Words for added security (highly recommended).
  internal static let exportBackupModalEncryptedDescription = T.tr("Localizable", "export_backup_modal_encrypted_description", fallback: "Your backup will be encrypted with your Master Password and Secret Words for added security (highly recommended).")
  /// Encrypted
  internal static let exportBackupModalEncryptedTitle = T.tr("Localizable", "export_backup_modal_encrypted_title", fallback: "Encrypted")
  /// Save to file
  internal static let exportBackupModalSaveToFile = T.tr("Localizable", "export_backup_modal_save_to_file", fallback: "Save to file")
  /// Share
  internal static let exportBackupModalShare = T.tr("Localizable", "export_backup_modal_share", fallback: "Share")
  /// Export your backup
  internal static let exportBackupModalTitle = T.tr("Localizable", "export_backup_modal_title", fallback: "Export your backup")
  /// Save exported Vault in a safe place
  internal static let exportVaultTitle = T.tr("Localizable", "export_vault_title", fallback: "Save exported Vault in a safe place")
  /// No local Vault was found. Reinstall the app
  internal static let generalErrorNoLocalVault = T.tr("Localizable", "general_error_no_local_vault", fallback: "No local Vault was found. Reinstall the app")
  /// Network error: %@
  internal static func generalNetworkErrorDetails(_ p1: Any) -> String {
    return T.tr("Localizable", "general_network_error_details", String(describing: p1), fallback: "Network error: %@")
  }
  /// Not Available
  internal static let generalNotAvailable = T.tr("Localizable", "general_not_available", fallback: "Not Available")
  /// Server error: %@
  internal static func generalServerErrorDetails(_ p1: Any) -> String {
    return T.tr("Localizable", "general_server_error_details", String(describing: p1), fallback: "Server error: %@")
  }
  /// Start with quick setup
  internal static let homeEmptyImportCta = T.tr("Localizable", "home_empty_import_cta", fallback: "Start with quick setup")
  /// No items yet
  internal static let homeEmptyTitle = T.tr("Localizable", "home_empty_title", fallback: "No items yet")
  /// Items
  internal static let homeTitle = T.tr("Localizable", "home_title", fallback: "Items")
  /// Master Password
  internal static let iosLockScreenUnlockTitle = T.tr("Localizable", "ios_lock_screen_unlock_title", fallback: "Master Password")
  /// Delete
  internal static let knownBrowserDeleteButton = T.tr("Localizable", "known_browser_delete_button", fallback: "Delete")
  /// Are you sure you want to disconnect this device from the selected browser extension?
  internal static let knownBrowserDeleteDialogBody = T.tr("Localizable", "known_browser_delete_dialog_body", fallback: "Are you sure you want to disconnect this device from the selected browser extension?")
  /// Delete browser extension?
  internal static let knownBrowserDeleteDialogTitle = T.tr("Localizable", "known_browser_delete_dialog_title", fallback: "Delete browser extension?")
  /// First connection:
  internal static let knownBrowserFirstConnectionPrefix = T.tr("Localizable", "known_browser_first_connection_prefix", fallback: "First connection:")
  /// Last connection:
  internal static let knownBrowserLastConnectionPrefix = T.tr("Localizable", "known_browser_last_connection_prefix", fallback: "Last connection:")
  /// List of trusted browser extensions that have been approved by you and don't need a confirmation to connect to this device.
  internal static let knownBrowsersDescription = T.tr("Localizable", "known_browsers_description", fallback: "List of trusted browser extensions that have been approved by you and don't need a confirmation to connect to this device.")
  /// No browsers found
  internal static let knownBrowsersEmpty = T.tr("Localizable", "known_browsers_empty", fallback: "No browsers found")
  /// Connected Browser Extensions
  internal static let knownBrowsersHeader = T.tr("Localizable", "known_browsers_header", fallback: "Connected Browser Extensions")
  /// Trusted Extensions
  internal static let knownBrowsersTitle = T.tr("Localizable", "known_browsers_title", fallback: "Trusted Extensions")
  /// Biometrics Error
  internal static let lockScreenBiometricsErrorTitle = T.tr("Localizable", "lock_screen_biometrics_error_title", fallback: "Biometrics Error")
  /// Too many failed attempts. You can enable biometrics later in Settings -> Security.
  internal static let lockScreenBiometricsErrorTooManyAttempts = T.tr("Localizable", "lock_screen_biometrics_error_too_many_attempts", fallback: "Too many failed attempts. You can enable biometrics later in Settings -> Security.")
  /// Enable biometrics
  internal static let lockScreenBiometricsModalSubtitle = T.tr("Localizable", "lock_screen_biometrics_modal_subtitle", fallback: "Enable biometrics")
  /// Biometrics
  internal static let lockScreenBiometricsModalTitle = T.tr("Localizable", "lock_screen_biometrics_modal_title", fallback: "Biometrics")
  /// Enable
  internal static let lockScreenBiometricsPromptAccept = T.tr("Localizable", "lock_screen_biometrics_prompt_accept", fallback: "Enable")
  /// Would you like to enable biometrics and use them instead of your password?
  internal static let lockScreenBiometricsPromptBody = T.tr("Localizable", "lock_screen_biometrics_prompt_body", fallback: "Would you like to enable biometrics and use them instead of your password?")
  /// Maybe later
  internal static let lockScreenBiometricsPromptCancel = T.tr("Localizable", "lock_screen_biometrics_prompt_cancel", fallback: "Maybe later")
  /// Enable Face ID
  internal static let lockScreenBiometricsPromptFaceidTitle = T.tr("Localizable", "lock_screen_biometrics_prompt_faceid_title", fallback: "Enable Face ID")
  /// Enable Biometrics?
  internal static let lockScreenBiometricsPromptTitle = T.tr("Localizable", "lock_screen_biometrics_prompt_title", fallback: "Enable Biometrics?")
  /// Enable Touch ID
  internal static let lockScreenBiometricsPromptTouchidTitle = T.tr("Localizable", "lock_screen_biometrics_prompt_touchid_title", fallback: "Enable Touch ID")
  /// Enter your Master Password
  internal static let lockScreenEnterMasterPassword = T.tr("Localizable", "lock_screen_enter_master_password", fallback: "Enter your Master Password")
  /// Reset app
  internal static let lockScreenResetApp = T.tr("Localizable", "lock_screen_reset_app", fallback: "Reset app")
  /// Are you sure? All content will be lost!
  internal static let lockScreenResetAppTitle = T.tr("Localizable", "lock_screen_reset_app_title", fallback: "Are you sure? All content will be lost!")
  /// 2FAS Pass access temporarily blocked due to failed master password attempts
  internal static let lockScreenTooManyAttemptsDescription = T.tr("Localizable", "lock_screen_too_many_attempts_description", fallback: "2FAS Pass access temporarily blocked due to failed master password attempts")
  /// Try again in: %@
  internal static func lockScreenTryAgain(_ p1: Any) -> String {
    return T.tr("Localizable", "lock_screen_try_again %@", String(describing: p1), fallback: "Try again in: %@")
  }
  /// Error while unlocking using Biometry
  internal static let lockScreenUnlockBiometricsError = T.tr("Localizable", "lock_screen_unlock_biometrics_error", fallback: "Error while unlocking using Biometry")
  /// Unlocking using Biometry
  internal static let lockScreenUnlockBiometricsReason = T.tr("Localizable", "lock_screen_unlock_biometrics_reason", fallback: "Unlocking using Biometry")
  /// Unlock
  internal static let lockScreenUnlockCta = T.tr("Localizable", "lock_screen_unlock_cta", fallback: "Unlock")
  /// Enter your Master Password to unlock the app
  internal static let lockScreenUnlockDescription = T.tr("Localizable", "lock_screen_unlock_description", fallback: "Enter your Master Password to unlock the app")
  /// Password is incorrect
  internal static let lockScreenUnlockInvalidPassword = T.tr("Localizable", "lock_screen_unlock_invalid_password", fallback: "Password is incorrect")
  /// Unlock App
  internal static let lockScreenUnlockTitle = T.tr("Localizable", "lock_screen_unlock_title", fallback: "Unlock App")
  /// Master Password
  internal static let lockScreenUnlockTitleIos = T.tr("Localizable", "lock_screen_unlock_title_ios", fallback: "Master Password")
  /// Use FaceID
  internal static let lockScreenUnlockUseFaceid = T.tr("Localizable", "lock_screen_unlock_use_faceid", fallback: "Use FaceID")
  /// Use TouchID
  internal static let lockScreenUnlockUseTouchid = T.tr("Localizable", "lock_screen_unlock_use_touchid", fallback: "Use TouchID")
  /// 10
  internal static let lockoutSettingsAppLockAttemptsCount10 = T.tr("Localizable", "lockout_settings_app_lock_attempts_count_10", fallback: "10")
  /// 3
  internal static let lockoutSettingsAppLockAttemptsCount3 = T.tr("Localizable", "lockout_settings_app_lock_attempts_count_3", fallback: "3")
  /// 5
  internal static let lockoutSettingsAppLockAttemptsCount5 = T.tr("Localizable", "lockout_settings_app_lock_attempts_count_5", fallback: "5")
  /// No limit
  internal static let lockoutSettingsAppLockAttemptsNoLimit = T.tr("Localizable", "lockout_settings_app_lock_attempts_no_limit", fallback: "No limit")
  /// 1 hour
  internal static let lockoutSettingsAppLockTimeHour1 = T.tr("Localizable", "lockout_settings_app_lock_time_hour_1", fallback: "1 hour")
  /// Immediately
  internal static let lockoutSettingsAppLockTimeImmediately = T.tr("Localizable", "lockout_settings_app_lock_time_immediately", fallback: "Immediately")
  /// 1 minute
  internal static let lockoutSettingsAppLockTimeMinute1 = T.tr("Localizable", "lockout_settings_app_lock_time_minute_1", fallback: "1 minute")
  /// 5 minutes
  internal static let lockoutSettingsAppLockTimeMinutes5 = T.tr("Localizable", "lockout_settings_app_lock_time_minutes_5", fallback: "5 minutes")
  /// 30 seconds
  internal static let lockoutSettingsAppLockTimeSeconds30 = T.tr("Localizable", "lockout_settings_app_lock_time_seconds_30", fallback: "30 seconds")
  /// Application Lockout
  internal static let lockoutSettingsAppLockoutHeader = T.tr("Localizable", "lockout_settings_app_lockout_header", fallback: "Application Lockout")
  /// 1 day
  internal static let lockoutSettingsAutofillLockTimeDay1 = T.tr("Localizable", "lockout_settings_autofill_lock_time_day_1", fallback: "1 day")
  /// 1 hour
  internal static let lockoutSettingsAutofillLockTimeHour1 = T.tr("Localizable", "lockout_settings_autofill_lock_time_hour_1", fallback: "1 hour")
  /// 15 minutes
  internal static let lockoutSettingsAutofillLockTimeMinutes15 = T.tr("Localizable", "lockout_settings_autofill_lock_time_minutes_15", fallback: "15 minutes")
  /// 30 minutes
  internal static let lockoutSettingsAutofillLockTimeMinutes30 = T.tr("Localizable", "lockout_settings_autofill_lock_time_minutes_30", fallback: "30 minutes")
  /// 5 minutes
  internal static let lockoutSettingsAutofillLockTimeMinutes5 = T.tr("Localizable", "lockout_settings_autofill_lock_time_minutes_5", fallback: "5 minutes")
  /// Never
  internal static let lockoutSettingsAutofillLockTimeNever = T.tr("Localizable", "lockout_settings_autofill_lock_time_never", fallback: "Never")
  /// Autofill Lockout
  internal static let lockoutSettingsAutofillLockoutHeader = T.tr("Localizable", "lockout_settings_autofill_lockout_header", fallback: "Autofill Lockout")
  /// Add Item
  internal static let loginAddTitle = T.tr("Localizable", "login_add_title", fallback: "Add Item")
  /// +  Add URL
  internal static let loginAddUriCta = T.tr("Localizable", "login_add_uri_cta", fallback: "+  Add URL")
  /// Are you sure you want to remove this Item? You can restore it later.
  internal static let loginDeleteConfirmBody = T.tr("Localizable", "login_delete_confirm_body", fallback: "Are you sure you want to remove this Item? You can restore it later.")
  /// Remove Item?
  internal static let loginDeleteConfirmTitle = T.tr("Localizable", "login_delete_confirm_title", fallback: "Remove Item?")
  /// Remove this Item from 2FAS Pass
  internal static let loginDeleteCta = T.tr("Localizable", "login_delete_cta", fallback: "Remove this Item from 2FAS Pass")
  /// Edit item
  internal static let loginEdit = T.tr("Localizable", "login_edit", fallback: "Edit item")
  /// Edit icon
  internal static let loginEditIconCta = T.tr("Localizable", "login_edit_icon_cta", fallback: "Edit icon")
  /// Edit Item
  internal static let loginEditTitle = T.tr("Localizable", "login_edit_title", fallback: "Edit Item")
  /// Item was deleted on another device. You can find it in the trash
  internal static let loginErrorDeletedOtherDevice = T.tr("Localizable", "login_error_deleted_other_device", fallback: "Item was deleted on another device. You can find it in the trash")
  /// Item was edited on another device
  internal static let loginErrorEditedOtherDevice = T.tr("Localizable", "login_error_edited_other_device", fallback: "Item was edited on another device")
  /// Error while trying to save Item
  internal static let loginErrorSave = T.tr("Localizable", "login_error_save", fallback: "Error while trying to save Item")
  /// From oldest
  internal static let loginFilterModalSortCreationDateAsc = T.tr("Localizable", "login_filter_modal_sort_creation_date_asc", fallback: "From oldest")
  /// From newest
  internal static let loginFilterModalSortCreationDateDesc = T.tr("Localizable", "login_filter_modal_sort_creation_date_desc", fallback: "From newest")
  /// Name (A-Z)
  internal static let loginFilterModalSortNameAsc = T.tr("Localizable", "login_filter_modal_sort_name_asc", fallback: "Name (A-Z)")
  /// Name (Z-A)
  internal static let loginFilterModalSortNameDesc = T.tr("Localizable", "login_filter_modal_sort_name_desc", fallback: "Name (Z-A)")
  /// Sort
  internal static let loginFilterModalTitle = T.tr("Localizable", "login_filter_modal_title", fallback: "Sort")
  /// Name
  internal static let loginNameLabel = T.tr("Localizable", "login_name_label", fallback: "Name")
  /// No Item Name
  internal static let loginNoItemName = T.tr("Localizable", "login_no_item_name", fallback: "No Item Name")
  /// Secure Notes
  internal static let loginNotesLabel = T.tr("Localizable", "login_notes_label", fallback: "Secure Notes")
  /// Auto-Generate
  internal static let loginPasswordAutogenerateCta = T.tr("Localizable", "login_password_autogenerate_cta", fallback: "Auto-Generate")
  /// Generator
  internal static let loginPasswordGeneratorCta = T.tr("Localizable", "login_password_generator_cta", fallback: "Generator")
  /// Password
  internal static let loginPasswordLabel = T.tr("Localizable", "login_password_label", fallback: "Password")
  /// Enter password
  internal static let loginPasswordPlaceholder = T.tr("Localizable", "login_password_placeholder", fallback: "Enter password")
  /// Take another try with a different search term
  internal static let loginSearchNoResultsDescription = T.tr("Localizable", "login_search_no_results_description", fallback: "Take another try with a different search term")
  /// Item not found
  internal static let loginSearchNoResultsTitle = T.tr("Localizable", "login_search_no_results_title", fallback: "Item not found")
  /// Security
  internal static let loginSecurityLevelHeader = T.tr("Localizable", "login_security_level_header", fallback: "Security")
  /// Security Tier
  internal static let loginSecurityLevelLabel = T.tr("Localizable", "login_security_level_label", fallback: "Security Tier")
  /// Access this password directly from the 2FAS Pass Browser Extension.
  internal static let loginSecurityTypeSecureDescription = T.tr("Localizable", "login_security_type_secure_description", fallback: "Access this password directly from the 2FAS Pass Browser Extension.")
  /// Secret
  internal static let loginSecurityTypeSecureTitle = T.tr("Localizable", "login_security_type_secure_title", fallback: "Secret")
  /// Do not share this password with 2FAS Pass Browser Extension and type it manually.
  internal static let loginSecurityTypeTopSecretDescription = T.tr("Localizable", "login_security_type_top_secret_description", fallback: "Do not share this password with 2FAS Pass Browser Extension and type it manually.")
  /// Top Secret
  internal static let loginSecurityTypeTopSecretTitle = T.tr("Localizable", "login_security_type_top_secret_title", fallback: "Top Secret")
  /// Share the password with the 2FAS Pass Browser Extension once after confirmation in the 2FAS Pass mobile app.
  internal static let loginSecurityTypeUltraSecureDescription = T.tr("Localizable", "login_security_type_ultra_secure_description", fallback: "Share the password with the 2FAS Pass Browser Extension once after confirmation in the 2FAS Pass mobile app.")
  /// Highly Secret
  internal static let loginSecurityTypeUltraSecureTitle = T.tr("Localizable", "login_security_type_ultra_secure_title", fallback: "Highly Secret")
  /// Do you want to discard your changes?
  internal static let loginUnsavedChangesDialogDescription = T.tr("Localizable", "login_unsaved_changes_dialog_description", fallback: "Do you want to discard your changes?")
  /// Unsaved changes
  internal static let loginUnsavedChangesDialogTitle = T.tr("Localizable", "login_unsaved_changes_dialog_title", fallback: "Unsaved changes")
  /// Incorrect URL: %@
  internal static func loginUriError(_ p1: Any) -> String {
    return T.tr("Localizable", "login_uri_error %@", String(describing: p1), fallback: "Incorrect URL: %@")
  }
  /// Website URL
  internal static let loginUriHeader = T.tr("Localizable", "login_uri_header", fallback: "Website URL")
  /// URL
  internal static let loginUriLabel = T.tr("Localizable", "login_uri_label", fallback: "URL")
  /// URL %lld
  internal static func loginUriLabelLld(_ p1: Int) -> String {
    return T.tr("Localizable", "login_uri_label %lld", p1, fallback: "URL %lld")
  }
  /// Resource matches URI's base domain.
  internal static let loginUriMatcherDomainDescription = T.tr("Localizable", "login_uri_matcher_domain_description", fallback: "Resource matches URI's base domain.")
  /// Domain
  internal static let loginUriMatcherDomainTitle = T.tr("Localizable", "login_uri_matcher_domain_title", fallback: "Domain")
  /// Resource is exactly the same as URI.
  internal static let loginUriMatcherExactDescription = T.tr("Localizable", "login_uri_matcher_exact_description", fallback: "Resource is exactly the same as URI.")
  /// Exact
  internal static let loginUriMatcherExactTitle = T.tr("Localizable", "login_uri_matcher_exact_title", fallback: "Exact")
  /// Resource matches URI's hostname and port.
  internal static let loginUriMatcherHostDescription = T.tr("Localizable", "login_uri_matcher_host_description", fallback: "Resource matches URI's hostname and port.")
  /// Host
  internal static let loginUriMatcherHostTitle = T.tr("Localizable", "login_uri_matcher_host_title", fallback: "Host")
  /// Resource starts with URI's text.
  internal static let loginUriMatcherStartsWithDescription = T.tr("Localizable", "login_uri_matcher_starts_with_description", fallback: "Resource starts with URI's text.")
  /// Start with
  internal static let loginUriMatcherStartsWithTitle = T.tr("Localizable", "login_uri_matcher_starts_with_title", fallback: "Start with")
  /// Username
  internal static let loginUsernameLabel = T.tr("Localizable", "login_username_label", fallback: "Username")
  /// Can't find any Usernames
  internal static let loginUsernameMostUsedEmpty = T.tr("Localizable", "login_username_most_used_empty", fallback: "Can't find any Usernames")
  /// Most used Usernames
  internal static let loginUsernameMostUsedHeader = T.tr("Localizable", "login_username_most_used_header", fallback: "Most used Usernames")
  /// Copy password
  internal static let loginViewActionCopyPassword = T.tr("Localizable", "login_view_action_copy_password", fallback: "Copy password")
  /// Copy username
  internal static let loginViewActionCopyUsername = T.tr("Localizable", "login_view_action_copy_username", fallback: "Copy username")
  /// Remove Item
  internal static let loginViewActionDelete = T.tr("Localizable", "login_view_action_delete", fallback: "Remove Item")
  /// Open Website
  internal static let loginViewActionOpenUri = T.tr("Localizable", "login_view_action_open_uri", fallback: "Open Website")
  /// URLs
  internal static let loginViewActionUrisTitle = T.tr("Localizable", "login_view_action_uris_title", fallback: "URLs")
  /// Item details
  internal static let loginViewActionViewDetails = T.tr("Localizable", "login_view_action_view_details", fallback: "Item details")
  /// Billed through Apple.
  internal static let manageSubscriptionAppleInfo = T.tr("Localizable", "manage_subscription_apple_info", fallback: "Billed through Apple.")
  /// Connected Web Browsers
  internal static let manageSubscriptionBrowsersTitle = T.tr("Localizable", "manage_subscription_browsers_title", fallback: "Connected Web Browsers")
  /// Your plan ends on 
  internal static let manageSubscriptionEndDatePrefix = T.tr("Localizable", "manage_subscription_end_date_prefix", fallback: "Your plan ends on ")
  /// Your logins and passwords
  internal static let manageSubscriptionItemsSubtitle = T.tr("Localizable", "manage_subscription_items_subtitle", fallback: "Your logins and passwords")
  /// Items
  internal static let manageSubscriptionItemsTitle = T.tr("Localizable", "manage_subscription_items_title", fallback: "Items")
  /// Multi-Device Sync
  internal static let manageSubscriptionMultiDeviceSyncTitle = T.tr("Localizable", "manage_subscription_multi_device_sync_title", fallback: "Multi-Device Sync")
  /// Annual Subscription: 
  internal static let manageSubscriptionPricePrefix = T.tr("Localizable", "manage_subscription_price_prefix", fallback: "Annual Subscription: ")
  /// Your plan will automatically renew on 
  internal static let manageSubscriptionRenewDatePrefix = T.tr("Localizable", "manage_subscription_renew_date_prefix", fallback: "Your plan will automatically renew on ")
  /// 2FAS Pass Unlimited
  internal static let manageSubscriptionTitle = T.tr("Localizable", "manage_subscription_title", fallback: "2FAS Pass Unlimited")
  /// Identifier
  internal static let manageSubscriptionUserIdentifierTitle = T.tr("Localizable", "manage_subscription_user_identifier_title", fallback: "Identifier")
  /// Confirm password
  internal static let masterPasswordConfirmLabel = T.tr("Localizable", "master_password_confirm_label", fallback: "Confirm password")
  /// Now, define a new Master Password and remember it by heart.
  internal static let masterPasswordCreateNew = T.tr("Localizable", "master_password_create_new", fallback: "Now, define a new Master Password and remember it by heart.")
  /// Now, define a Master Password and remember it by heart.
  internal static let masterPasswordDefine = T.tr("Localizable", "master_password_define", fallback: "Now, define a Master Password and remember it by heart.")
  /// Password
  internal static let masterPasswordLabel = T.tr("Localizable", "master_password_label", fallback: "Password")
  /// Use at least %lld characters
  internal static func masterPasswordMinLengthLld(_ p1: Int) -> String {
    return T.tr("Localizable", "master_password_min_length %lld", p1, fallback: "Use at least %lld characters")
  }
  /// The passwords don't match
  internal static let masterPasswordNotMatch = T.tr("Localizable", "master_password_not_match", fallback: "The passwords don't match")
  /// Please restart the app and try again
  internal static let migrationErrorBody = T.tr("Localizable", "migration_error_body", fallback: "Please restart the app and try again")
  /// Migration failed
  internal static let migrationErrorTitle = T.tr("Localizable", "migration_error_title", fallback: "Migration failed")
  /// It is used to unlock the app and recover your 2FAS Pass Vault.
  internal static let onboardingCreateMasterPasswordDescription = T.tr("Localizable", "onboarding_create_master_password_description", fallback: "It is used to unlock the app and recover your 2FAS Pass Vault.")
  /// This simple tutorial will help you prepare and memorize your Master Password.
  internal static let onboardingCreateMasterPasswordGuideDescription = T.tr("Localizable", "onboarding_create_master_password_guide_description", fallback: "This simple tutorial will help you prepare and memorize your Master Password.")
  /// A Simple Guide
  internal static let onboardingCreateMasterPasswordGuideTitle = T.tr("Localizable", "onboarding_create_master_password_guide_title", fallback: "A Simple Guide")
  /// Create Master Password
  internal static let onboardingCreateMasterPasswordTitle = T.tr("Localizable", "onboarding_create_master_password_title", fallback: "Create Master Password")
  /// Tap and hold
  internal static let onboardingGenerateSecretKeyCta = T.tr("Localizable", "onboarding_generate_secret_key_cta", fallback: "Tap and hold")
  /// It is a 15-word phrase used to authenticate your 2FAS Pass Vault.
  internal static let onboardingGenerateSecretKeyDescription = T.tr("Localizable", "onboarding_generate_secret_key_description", fallback: "It is a 15-word phrase used to authenticate your 2FAS Pass Vault.")
  /// Secret Words have been generated successfully and saved in your 2FAS Pass Vault.
  internal static let onboardingGenerateSecretKeySuccessDescription = T.tr("Localizable", "onboarding_generate_secret_key_success_description", fallback: "Secret Words have been generated successfully and saved in your 2FAS Pass Vault.")
  /// Secret Words Generated!
  internal static let onboardingGenerateSecretKeySuccessTitle = T.tr("Localizable", "onboarding_generate_secret_key_success_title", fallback: "Secret Words Generated!")
  /// Generate Secret Words
  internal static let onboardingGenerateSecretKeyTitle = T.tr("Localizable", "onboarding_generate_secret_key_title", fallback: "Generate Secret Words")
  /// Look around and select 3 objects (e.g.: Flower, Candle, Bookshelf).
  internal static let onboardingGuide1 = T.tr("Localizable", "onboarding_guide_1", fallback: "Look around and select 3 objects (e.g.: Flower, Candle, Bookshelf).")
  /// Think about short story that connects these 3 objects (for example: A Flower and a Candle lays on the Bookshelf.)
  internal static let onboardingGuide2 = T.tr("Localizable", "onboarding_guide_2", fallback: "Think about short story that connects these 3 objects (for example: A Flower and a Candle lays on the Bookshelf.)")
  /// Selected objects are the words in your password. The story helps you remember them. Now think about the separator between the words (e.g.: # or $).
  internal static let onboardingGuide3 = T.tr("Localizable", "onboarding_guide_3", fallback: "Selected objects are the words in your password. The story helps you remember them. Now think about the separator between the words (e.g.: # or $).")
  /// The strong, unique, and easy-to-remember password looks like this Object1 #Object2 #Object3 (e.g. Flower#Candle#Bookshelf)
  internal static let onboardingGuide4 = T.tr("Localizable", "onboarding_guide_4", fallback: "The strong, unique, and easy-to-remember password looks like this Object1 #Object2 #Object3 (e.g. Flower#Candle#Bookshelf)")
  /// Start using 2FAS Pass
  internal static let onboardingProgressCompletedCta = T.tr("Localizable", "onboarding_progress_completed_cta", fallback: "Start using 2FAS Pass")
  /// Your Vault has been successfully created and encrypted!
  internal static let onboardingProgressCompletedDescription = T.tr("Localizable", "onboarding_progress_completed_description", fallback: "Your Vault has been successfully created and encrypted!")
  /// Setup complete!
  internal static let onboardingProgressCompletedTitle = T.tr("Localizable", "onboarding_progress_completed_title", fallback: "Setup complete!")
  /// Now it’s time to create your Master Password.
  internal static let onboardingProgressHalfwayDescription = T.tr("Localizable", "onboarding_progress_halfway_description", fallback: "Now it’s time to create your Master Password.")
  /// You are halfway there
  internal static let onboardingProgressHalfwayTitle = T.tr("Localizable", "onboarding_progress_halfway_title", fallback: "You are halfway there")
  /// Your local secure storage.
  internal static let onboardingProgressStartDescription = T.tr("Localizable", "onboarding_progress_start_description", fallback: "Your local secure storage.")
  /// 2FAS Pass Vault
  internal static let onboardingProgressStartTitle = T.tr("Localizable", "onboarding_progress_start_title", fallback: "2FAS Pass Vault")
  /// It is a 15-word phrase used to authenticate your 2FAS Pass Vault.
  internal static let onboardingProgressStep1Description = T.tr("Localizable", "onboarding_progress_step1_description", fallback: "It is a 15-word phrase used to authenticate your 2FAS Pass Vault.")
  /// 1. Generate Secret Words
  internal static let onboardingProgressStep1Title = T.tr("Localizable", "onboarding_progress_step1_title", fallback: "1. Generate Secret Words")
  /// It is used to unlock the app and recover your 2FAS Pass Vault.
  internal static let onboardingProgressStep2Description = T.tr("Localizable", "onboarding_progress_step2_description", fallback: "It is used to unlock the app and recover your 2FAS Pass Vault.")
  /// 2. Create Master Password
  internal static let onboardingProgressStep2Title = T.tr("Localizable", "onboarding_progress_step2_title", fallback: "2. Create Master Password")
  /// Vault Encryption Setup
  internal static let onboardingProgressStepsHeader = T.tr("Localizable", "onboarding_progress_steps_header", fallback: "Vault Encryption Setup")
  /// Keep your Items local on your own device.
  internal static let onboardingWelcome1Description = T.tr("Localizable", "onboarding_welcome1_description", fallback: "Keep your Items local on your own device.")
  /// No third-party control of your Items
  internal static let onboardingWelcome1Feature1 = T.tr("Localizable", "onboarding_welcome1_feature1", fallback: "No third-party control of your Items")
  /// Assured anonymity and data security
  internal static let onboardingWelcome1Feature2 = T.tr("Localizable", "onboarding_welcome1_feature2", fallback: "Assured anonymity and data security")
  /// No user accounts required
  internal static let onboardingWelcome1Feature3 = T.tr("Localizable", "onboarding_welcome1_feature3", fallback: "No user accounts required")
  /// Local-first Password Manager
  internal static let onboardingWelcome1Title = T.tr("Localizable", "onboarding_welcome1_title", fallback: "Local-first Password Manager")
  /// Only you have access to your Items. We, or any third party, do not.
  internal static let onboardingWelcome2Description = T.tr("Localizable", "onboarding_welcome2_description", fallback: "Only you have access to your Items. We, or any third party, do not.")
  /// Advanced Items encryption
  internal static let onboardingWelcome2Feature1 = T.tr("Localizable", "onboarding_welcome2_feature1", fallback: "Advanced Items encryption")
  /// Self-hosted / WebDAV integration
  internal static let onboardingWelcome2Feature2 = T.tr("Localizable", "onboarding_welcome2_feature2", fallback: "Self-hosted / WebDAV integration")
  /// No risk of vendor lock-in
  internal static let onboardingWelcome2Feature3 = T.tr("Localizable", "onboarding_welcome2_feature3", fallback: "No risk of vendor lock-in")
  /// Own your Items
  internal static let onboardingWelcome2Title = T.tr("Localizable", "onboarding_welcome2_title", fallback: "Own your Items")
  /// Securely add and autofill Items with the next-gen 2FAS Pass Browser Extension.
  internal static let onboardingWelcome3Description = T.tr("Localizable", "onboarding_welcome3_description", fallback: "Securely add and autofill Items with the next-gen 2FAS Pass Browser Extension.")
  /// Speeds up the sign-in process
  internal static let onboardingWelcome3Feature1 = T.tr("Localizable", "onboarding_welcome3_feature1", fallback: "Speeds up the sign-in process")
  /// Multi-layer encryption
  internal static let onboardingWelcome3Feature2 = T.tr("Localizable", "onboarding_welcome3_feature2", fallback: "Multi-layer encryption")
  /// Item Security Tiers
  internal static let onboardingWelcome3Feature3 = T.tr("Localizable", "onboarding_welcome3_feature3", fallback: "Item Security Tiers")
  /// Web Browser Extension
  internal static let onboardingWelcome3Title = T.tr("Localizable", "onboarding_welcome3_title", fallback: "Web Browser Extension")
  /// Get Started
  internal static let onboardingWelcomeCta1 = T.tr("Localizable", "onboarding_welcome_cta1", fallback: "Get Started")
  /// Recover / Synchronize
  internal static let onboardingWelcomeCta2 = T.tr("Localizable", "onboarding_welcome_cta2", fallback: "Recover / Synchronize")
  /// Opening a 2FAS Pass backup file is not supported. Go to 2FAS Pass Settings to import it.
  internal static let openExternalFileErrorBody = T.tr("Localizable", "open_external_file_error_body", fallback: "Opening a 2FAS Pass backup file is not supported. Go to 2FAS Pass Settings to import it.")
  /// Error while copying password
  internal static let passwordErrorCopyPassword = T.tr("Localizable", "password_error_copy_password", fallback: "Error while copying password")
  /// Error while copying username
  internal static let passwordErrorCopyUsername = T.tr("Localizable", "password_error_copy_username", fallback: "Error while copying username")
  /// Characters
  internal static let passwordGeneratorCharacters = T.tr("Localizable", "password_generator_characters", fallback: "Characters")
  /// Copy
  internal static let passwordGeneratorCopyCta = T.tr("Localizable", "password_generator_copy_cta", fallback: "Copy")
  /// Digits
  internal static let passwordGeneratorDigits = T.tr("Localizable", "password_generator_digits", fallback: "Digits")
  /// Generate
  internal static let passwordGeneratorGenerateCta = T.tr("Localizable", "password_generator_generate_cta", fallback: "Generate")
  /// Password Generator
  internal static let passwordGeneratorHeader = T.tr("Localizable", "password_generator_header", fallback: "Password Generator")
  /// Special characters
  internal static let passwordGeneratorSpecialCharacters = T.tr("Localizable", "password_generator_special_characters", fallback: "Special characters")
  /// Uppercase characters
  internal static let passwordGeneratorUppercaseCharacters = T.tr("Localizable", "password_generator_uppercase_characters", fallback: "Uppercase characters")
  /// Use password
  internal static let passwordGeneratorUseCta = T.tr("Localizable", "password_generator_use_cta", fallback: "Use password")
  /// At least 9 characters
  internal static let passwordLengthRequirement = T.tr("Localizable", "password_length_requirement", fallback: "At least 9 characters")
  /// Passwords match
  internal static let passwordsMatchText = T.tr("Localizable", "passwords_match_text", fallback: "Passwords match")
  /// You have reached your limit. Upgrade your plan to sync unlimited devices.
  internal static let paywallNoticeBrowsersLimitMsg = T.tr("Localizable", "paywall_notice_browsers_limit_msg", fallback: "You have reached your limit. Upgrade your plan to sync unlimited devices.")
  /// Can't connect
  internal static let paywallNoticeBrowsersLimitTitle = T.tr("Localizable", "paywall_notice_browsers_limit_title", fallback: "Can't connect")
  /// Upgrade plan
  internal static let paywallNoticeCta = T.tr("Localizable", "paywall_notice_cta", fallback: "Upgrade plan")
  /// Can’t import Items
  internal static let paywallNoticeItemsLimitImportTitle = T.tr("Localizable", "paywall_notice_items_limit_import_title", fallback: "Can’t import Items")
  /// You’ve reached the limit of %d Items. Upgrade your plan for unlimited Items.
  internal static func paywallNoticeItemsLimitReachedMsg(_ p1: Int) -> String {
    return T.tr("Localizable", "paywall_notice_items_limit_reached_msg", p1, fallback: "You’ve reached the limit of %d Items. Upgrade your plan for unlimited Items.")
  }
  /// Item limit reached
  internal static let paywallNoticeItemsLimitReachedTitle = T.tr("Localizable", "paywall_notice_items_limit_reached_title", fallback: "Item limit reached")
  /// Can’t restore Items
  internal static let paywallNoticeItemsLimitRestoreTitle = T.tr("Localizable", "paywall_notice_items_limit_restore_title", fallback: "Can’t restore Items")
  /// Can’t transfer Items
  internal static let paywallNoticeItemsLimitTransferTitle = T.tr("Localizable", "paywall_notice_items_limit_transfer_title", fallback: "Can’t transfer Items")
  /// Matching Vault exists in the backup but is linked to another device. Upgrade your plan to enable multi-device sync.
  internal static let paywallNoticeMultiDeviceMsg = T.tr("Localizable", "paywall_notice_multi_device_msg", fallback: "Matching Vault exists in the backup but is linked to another device. Upgrade your plan to enable multi-device sync.")
  /// Camera permission is required to scan QR Codes. To use this feature, go to Application Permissions and allow the app to access the camera.
  internal static let permissionCameraMsg = T.tr("Localizable", "permission_camera_msg", fallback: "Camera permission is required to scan QR Codes. To use this feature, go to Application Permissions and allow the app to access the camera.")
  /// Camera Permission
  internal static let permissionCameraTitle = T.tr("Localizable", "permission_camera_title", fallback: "Camera Permission")
  /// The app requires access to Push Notifications to access the browser extension functionality. You can change this setting at any time in System Settings.
  internal static let permissionNotificationsMsg = T.tr("Localizable", "permission_notifications_msg", fallback: "The app requires access to Push Notifications to access the browser extension functionality. You can change this setting at any time in System Settings.")
  /// Push Notifications
  internal static let permissionNotificationsTitle = T.tr("Localizable", "permission_notifications_title", fallback: "Push Notifications")
  /// New request from browser
  internal static let pushBrowserRequestGenericMessage = T.tr("Localizable", "push_browser_request_generic_message", fallback: "New request from browser")
  /// New request from %@
  internal static func pushBrowserRequestMessage(_ p1: Any) -> String {
    return T.tr("Localizable", "push_browser_request_message", String(describing: p1), fallback: "New request from %@")
  }
  /// 2FAS Pass request
  internal static let pushBrowserRequestTitle = T.tr("Localizable", "push_browser_request_title", fallback: "2FAS Pass request")
  /// Select 2FAS Pass to automatically fill in Item details in other apps.
  internal static let quickSetupAutofillDescription = T.tr("Localizable", "quick_setup_autofill_description", fallback: "Select 2FAS Pass to automatically fill in Item details in other apps.")
  /// AutoFill
  internal static let quickSetupAutofillTitle = T.tr("Localizable", "quick_setup_autofill_title", fallback: "AutoFill")
  /// Securely sync your data using iCloud in case this device gets lost or damaged.
  internal static let quickSetupIcloudSyncDescription = T.tr("Localizable", "quick_setup_icloud_sync_description", fallback: "Securely sync your data using iCloud in case this device gets lost or damaged.")
  /// Failed to enable vault sync
  internal static let quickSetupIcloudSyncFailure = T.tr("Localizable", "quick_setup_icloud_sync_failure", fallback: "Failed to enable vault sync")
  /// Vault Sync
  internal static let quickSetupIcloudSyncTitle = T.tr("Localizable", "quick_setup_icloud_sync_title", fallback: "Vault Sync")
  /// Import Items from 2FAS Pass Backup
  internal static let quickSetupImportItemsCta = T.tr("Localizable", "quick_setup_import_items_cta", fallback: "Import Items from 2FAS Pass Backup")
  /// Recommended
  internal static let quickSetupRecommended = T.tr("Localizable", "quick_setup_recommended", fallback: "Recommended")
  /// Default
  internal static let quickSetupSecurityTierDefaultLabel = T.tr("Localizable", "quick_setup_security_tier_default_label", fallback: "Default")
  /// Decide how to use individual Items with Autofill and share them with the Browser Extension.
  internal static let quickSetupSecurityTierDescription = T.tr("Localizable", "quick_setup_security_tier_description", fallback: "Decide how to use individual Items with Autofill and share them with the Browser Extension.")
  /// Security Tier
  internal static let quickSetupSecurityTierTitle = T.tr("Localizable", "quick_setup_security_tier_title", fallback: "Security Tier")
  /// Personlize your security and usability preferences.
  internal static let quickSetupSubtitle = T.tr("Localizable", "quick_setup_subtitle", fallback: "Personlize your security and usability preferences.")
  /// Quick setup
  internal static let quickSetupTitle = T.tr("Localizable", "quick_setup_title", fallback: "Quick setup")
  /// Transfer passwords from other apps
  internal static let quickSetupTransferItemsCta = T.tr("Localizable", "quick_setup_transfer_items_cta", fallback: "Transfer passwords from other apps")
  /// User is forbidden to access this path.
  internal static let recoveryErrorForbidden = T.tr("Localizable", "recovery_error_forbidden", fallback: "User is forbidden to access this path.")
  /// Index file is damaged.
  internal static let recoveryErrorIndexDamaged = T.tr("Localizable", "recovery_error_index_damaged", fallback: "Index file is damaged.")
  /// Index file not found. The backup folder is empty.
  internal static let recoveryErrorIndexNotFound = T.tr("Localizable", "recovery_error_index_not_found", fallback: "Index file not found. The backup folder is empty.")
  /// Existing backup was created using newer version. Update the app.
  internal static let recoveryErrorNewerVersion = T.tr("Localizable", "recovery_error_newer_version", fallback: "Existing backup was created using newer version. Update the app.")
  /// Nothing to import. Backup file has no passwords.
  internal static let recoveryErrorNothingToImport = T.tr("Localizable", "recovery_error_nothing_to_import", fallback: "Nothing to import. Backup file has no passwords.")
  /// User is not authorized to access this path.
  internal static let recoveryErrorUnauthorized = T.tr("Localizable", "recovery_error_unauthorized", fallback: "User is not authorized to access this path.")
  /// Vault file is damaged.
  internal static let recoveryErrorVaultDamaged = T.tr("Localizable", "recovery_error_vault_damaged", fallback: "Vault file is damaged.")
  /// Vault file not found. The backup folder is empty.
  internal static let recoveryErrorVaultNotFound = T.tr("Localizable", "recovery_error_vault_not_found", fallback: "Vault file not found. The backup folder is empty.")
  /// 2FAS Pass
  internal static let recoveryKitAuthor = T.tr("Localizable", "recovery_kit_author", fallback: "2FAS Pass")
  /// 2FAS Pass
  internal static let recoveryKitCreator = T.tr("Localizable", "recovery_kit_creator", fallback: "2FAS Pass")
  /// 2FAS Pass Recovery Kit
  internal static let recoveryKitHeader = T.tr("Localizable", "recovery_kit_header", fallback: "2FAS Pass Recovery Kit")
  /// 2FAS Pass Recovery Kit
  internal static let recoveryKitTitle = T.tr("Localizable", "recovery_kit_title", fallback: "2FAS Pass Recovery Kit")
  /// Write down the Master Password:
  internal static let recoveryKitWriteDown = T.tr("Localizable", "recovery_kit_write_down", fallback: "Write down the Master Password:")
  /// Close
  internal static let requestModalErrorGenericCta = T.tr("Localizable", "request_modal_error_generic_cta", fallback: "Close")
  /// Something went wrong. Please try again.
  internal static let requestModalErrorGenericSubtitle = T.tr("Localizable", "request_modal_error_generic_subtitle", fallback: "Something went wrong. Please try again.")
  /// Error occurred
  internal static let requestModalErrorGenericTitle = T.tr("Localizable", "request_modal_error_generic_title", fallback: "Error occurred")
  /// Upgrade plan
  internal static let requestModalErrorItemsLimitCta = T.tr("Localizable", "request_modal_error_items_limit_cta", fallback: "Upgrade plan")
  /// You’ve reached the limit of %d Items. Upgrade your plan for unlimited Items.
  internal static func requestModalErrorItemsLimitSubtitle(_ p1: Int) -> String {
    return T.tr("Localizable", "request_modal_error_items_limit_subtitle", p1, fallback: "You’ve reached the limit of %d Items. Upgrade your plan for unlimited Items.")
  }
  /// Items limit reached
  internal static let requestModalErrorItemsLimitTitle = T.tr("Localizable", "request_modal_error_items_limit_title", fallback: "Items limit reached")
  /// Close
  internal static let requestModalErrorNoItemCta = T.tr("Localizable", "request_modal_error_no_item_cta", fallback: "Close")
  /// Browser Extension wants to access an Item that does not exist in your Vault.
  internal static let requestModalErrorNoItemSubtitle = T.tr("Localizable", "request_modal_error_no_item_subtitle", fallback: "Browser Extension wants to access an Item that does not exist in your Vault.")
  /// Item does not exist
  internal static let requestModalErrorNoItemTitle = T.tr("Localizable", "request_modal_error_no_item_title", fallback: "Item does not exist")
  /// Item was saved on this device, but couldn't be sent to your browser. To send it, please reconnect to your browser extension.
  internal static let requestModalErrorSendDataSubtitle = T.tr("Localizable", "request_modal_error_send_data_subtitle", fallback: "Item was saved on this device, but couldn't be sent to your browser. To send it, please reconnect to your browser extension.")
  /// Item saved only on this device
  internal static let requestModalErrorSendDataTitle = T.tr("Localizable", "request_modal_error_send_data_title", fallback: "Item saved only on this device")
  /// Request from 2FAS Pass
  internal static let requestModalHeaderTitle = T.tr("Localizable", "request_modal_header_title", fallback: "Request from 2FAS Pass")
  /// Connecting…
  internal static let requestModalLoading = T.tr("Localizable", "request_modal_loading", fallback: "Connecting…")
  /// Cancel
  internal static let requestModalNewItemCtaNegative = T.tr("Localizable", "request_modal_new_item_cta_negative", fallback: "Cancel")
  /// Continue
  internal static let requestModalNewItemCtaPositive = T.tr("Localizable", "request_modal_new_item_cta_positive", fallback: "Continue")
  /// Browser Extension asks you to add a new Item to your Vault
  internal static let requestModalNewItemSubtitle = T.tr("Localizable", "request_modal_new_item_subtitle", fallback: "Browser Extension asks you to add a new Item to your Vault")
  /// New Item
  internal static let requestModalNewItemTitle = T.tr("Localizable", "request_modal_new_item_title", fallback: "New Item")
  /// Cancel
  internal static let requestModalPasswordRequestCtaNegative = T.tr("Localizable", "request_modal_password_request_cta_negative", fallback: "Cancel")
  /// Send
  internal static let requestModalPasswordRequestCtaPositive = T.tr("Localizable", "request_modal_password_request_cta_positive", fallback: "Send")
  /// Browser extension requests the password of this Item for 3 minutes
  internal static let requestModalPasswordRequestSubtitle = T.tr("Localizable", "request_modal_password_request_subtitle", fallback: "Browser extension requests the password of this Item for 3 minutes")
  /// Password Request
  internal static let requestModalPasswordRequestTitle = T.tr("Localizable", "request_modal_password_request_title", fallback: "Password Request")
  /// Cancel
  internal static let requestModalRemoveItemCtaNegative = T.tr("Localizable", "request_modal_remove_item_cta_negative", fallback: "Cancel")
  /// Remove
  internal static let requestModalRemoveItemCtaPositive = T.tr("Localizable", "request_modal_remove_item_cta_positive", fallback: "Remove")
  /// Browser Extension asks you to remove the following Item from your Vault
  internal static let requestModalRemoveItemSubtitle = T.tr("Localizable", "request_modal_remove_item_subtitle", fallback: "Browser Extension asks you to remove the following Item from your Vault")
  /// Remove Item
  internal static let requestModalRemoveItemTitle = T.tr("Localizable", "request_modal_remove_item_title", fallback: "Remove Item")
  /// Request canceled!
  internal static let requestModalToastCancel = T.tr("Localizable", "request_modal_toast_cancel", fallback: "Request canceled!")
  /// Item added successfully!
  internal static let requestModalToastSuccessAddLogin = T.tr("Localizable", "request_modal_toast_success_add_login", fallback: "Item added successfully!")
  /// Item deleted successfully!
  internal static let requestModalToastSuccessDeleteLogin = T.tr("Localizable", "request_modal_toast_success_delete_login", fallback: "Item deleted successfully!")
  /// Password sent successfully!
  internal static let requestModalToastSuccessPasswordRequest = T.tr("Localizable", "request_modal_toast_success_password_request", fallback: "Password sent successfully!")
  /// Item updated successfully!
  internal static let requestModalToastSuccessUpdateLogin = T.tr("Localizable", "request_modal_toast_success_update_login", fallback: "Item updated successfully!")
  /// Cancel
  internal static let requestModalUpdateItemCtaNegative = T.tr("Localizable", "request_modal_update_item_cta_negative", fallback: "Cancel")
  /// Continue
  internal static let requestModalUpdateItemCtaPositive = T.tr("Localizable", "request_modal_update_item_cta_positive", fallback: "Continue")
  /// Browser Extension requests the update of the following fields of this Item.
  internal static let requestModalUpdateItemSubtitle = T.tr("Localizable", "request_modal_update_item_subtitle", fallback: "Browser Extension requests the update of the following fields of this Item.")
  /// Update Item
  internal static let requestModalUpdateItemTitle = T.tr("Localizable", "request_modal_update_item_title", fallback: "Update Item")
  /// Below, you can see a list of files from various devices. Click on the one that interests you to select it.
  internal static let restoreCloudFilesDescription = T.tr("Localizable", "restore_cloud_files_description", fallback: "Below, you can see a list of files from various devices. Click on the one that interests you to select it.")
  /// No Vaults found in your cloud storage
  internal static let restoreCloudFilesEmptyDescription = T.tr("Localizable", "restore_cloud_files_empty_description", fallback: "No Vaults found in your cloud storage")
  /// Your files
  internal static let restoreCloudFilesHeader = T.tr("Localizable", "restore_cloud_files_header", fallback: "Your files")
  /// ID: %@
  internal static func restoreCloudFilesId(_ p1: Any) -> String {
    return T.tr("Localizable", "restore_cloud_files_id %@", String(describing: p1), fallback: "ID: %@")
  }
  /// Your Vaults
  internal static let restoreCloudFilesTitle = T.tr("Localizable", "restore_cloud_files_title", fallback: "Your Vaults")
  /// Updated at: %@
  internal static func restoreCloudFilesUpdatedAt(_ p1: Any) -> String {
    return T.tr("Localizable", "restore_cloud_files_updated_at %@", String(describing: p1), fallback: "Updated at: %@")
  }
  /// To proceed, enter your Secret Words and Master Password using one of the available methods to decrypt a backup file
  internal static let restoreDecryptVaultDescription = T.tr("Localizable", "restore_decrypt_vault_description", fallback: "To proceed, enter your Secret Words and Master Password using one of the available methods to decrypt a backup file")
  /// Local Decryption Kit File
  internal static let restoreDecryptVaultOptionFile = T.tr("Localizable", "restore_decrypt_vault_option_file", fallback: "Local Decryption Kit File")
  /// Select a PDF file
  internal static let restoreDecryptVaultOptionFileDescription = T.tr("Localizable", "restore_decrypt_vault_option_file_description", fallback: "Select a PDF file")
  /// Manual Input
  internal static let restoreDecryptVaultOptionManual = T.tr("Localizable", "restore_decrypt_vault_option_manual", fallback: "Manual Input")
  /// Manually enter Secret Words
  internal static let restoreDecryptVaultOptionManualDescription = T.tr("Localizable", "restore_decrypt_vault_option_manual_description", fallback: "Manually enter Secret Words")
  /// Printed Decryption Kit
  internal static let restoreDecryptVaultOptionScanQr = T.tr("Localizable", "restore_decrypt_vault_option_scan_qr", fallback: "Printed Decryption Kit")
  /// Scan QR code
  internal static let restoreDecryptVaultOptionScanQrDescription = T.tr("Localizable", "restore_decrypt_vault_option_scan_qr_description", fallback: "Scan QR code")
  /// Decrypt Your Backup
  internal static let restoreDecryptVaultTitle = T.tr("Localizable", "restore_decrypt_vault_title", fallback: "Decrypt Your Backup")
  /// Enter words manually
  internal static let restoreEnterWordsTitle = T.tr("Localizable", "restore_enter_words_title", fallback: "Enter words manually")
  /// Error. Something went wrong. Try again.
  internal static let restoreErrorGeneral = T.tr("Localizable", "restore_error_general", fallback: "Error. Something went wrong. Try again.")
  /// Error. Incorrect QR Code.
  internal static let restoreErrorIncorrectQrCode = T.tr("Localizable", "restore_error_incorrect_qr_code", fallback: "Error. Incorrect QR Code.")
  /// Error. Incorrect Words.
  internal static let restoreErrorIncorrectWords = T.tr("Localizable", "restore_error_incorrect_words", fallback: "Error. Incorrect Words.")
  /// Did you use the correct Recover Kit?
  internal static let restoreFailureDescription = T.tr("Localizable", "restore_failure_description", fallback: "Did you use the correct Recover Kit?")
  /// Error while trying to recover the Vault
  internal static let restoreFailureTitle = T.tr("Localizable", "restore_failure_title", fallback: "Error while trying to recover the Vault")
  /// Error while fetching iCloud contents
  internal static let restoreIcloudFilesError = T.tr("Localizable", "restore_icloud_files_error", fallback: "Error while fetching iCloud contents")
  /// Select file
  internal static let restoreIcloudFilesTitle = T.tr("Localizable", "restore_icloud_files_title", fallback: "Select file")
  /// Error importing file
  internal static let restoreImportingFileErrorText = T.tr("Localizable", "restore_importing_file_error_text", fallback: "Error importing file")
  /// Importing backup file…
  internal static let restoreImportingFileText = T.tr("Localizable", "restore_importing_file_text", fallback: "Importing backup file…")
  /// Incorrect words
  internal static let restoreManualKeyIncorrectWords = T.tr("Localizable", "restore_manual_key_incorrect_words", fallback: "Incorrect words")
  /// Enter your Secret Words (15-word phrase)
  internal static let restoreManualKeyInputDescription = T.tr("Localizable", "restore_manual_key_input_description", fallback: "Enter your Secret Words (15-word phrase)")
  /// Manual Input
  internal static let restoreManualKeyInputTitle = T.tr("Localizable", "restore_manual_key_input_title", fallback: "Manual Input")
  /// Word %@
  internal static func restoreManualWord(_ p1: Any) -> String {
    return T.tr("Localizable", "restore_manual_word", String(describing: p1), fallback: "Word %@")
  }
  /// Enter your Vault's Master Password
  internal static let restoreMasterPasswordDescription = T.tr("Localizable", "restore_master_password_description", fallback: "Enter your Vault's Master Password")
  /// Master Password
  internal static let restoreMasterPasswordLabel = T.tr("Localizable", "restore_master_password_label", fallback: "Master Password")
  /// Master Password
  internal static let restoreMasterPasswordTitle = T.tr("Localizable", "restore_master_password_title", fallback: "Master Password")
  /// Hover over the QR code and wait for a moment
  internal static let restoreQrCodeCameraDescription = T.tr("Localizable", "restore_qr_code_camera_description", fallback: "Hover over the QR code and wait for a moment")
  /// Scan QR code
  internal static let restoreQrCodeCameraTitle = T.tr("Localizable", "restore_qr_code_camera_title", fallback: "Scan QR code")
  /// The camera is unavailable. Check the 2FAS Pass camera access in System Settings
  internal static let restoreQrCodeError = T.tr("Localizable", "restore_qr_code_error", fallback: "The camera is unavailable. Check the 2FAS Pass camera access in System Settings")
  /// System Settings
  internal static let restoreQrCodeErrorSystemSettings = T.tr("Localizable", "restore_qr_code_error_system_settings", fallback: "System Settings")
  /// Scan QR code
  internal static let restoreQrCodeIntroCta = T.tr("Localizable", "restore_qr_code_intro_cta", fallback: "Scan QR code")
  /// Scan the QR code or manually enter the Secret Words
  internal static let restoreQrCodeIntroDescription = T.tr("Localizable", "restore_qr_code_intro_description", fallback: "Scan the QR code or manually enter the Secret Words")
  /// Use the printed Decryption Kit
  internal static let restoreQrCodeIntroTitle = T.tr("Localizable", "restore_qr_code_intro_title", fallback: "Use the printed Decryption Kit")
  /// Reading backup file…
  internal static let restoreReadingFileText = T.tr("Localizable", "restore_reading_file_text", fallback: "Reading backup file…")
  /// Start using app
  internal static let restoreSuccessCta = T.tr("Localizable", "restore_success_cta", fallback: "Start using app")
  /// Start using the 2FAS Pass app on this device.
  internal static let restoreSuccessDescription = T.tr("Localizable", "restore_success_description", fallback: "Start using the 2FAS Pass app on this device.")
  /// Your Vault is restored!
  internal static let restoreSuccessTitle = T.tr("Localizable", "restore_success_title", fallback: "Your Vault is restored!")
  /// To import it, create a new Vault and navigate to **Settings → Import/Export**.
  internal static let restoreUnencryptedFileCtaDescriptionIos = T.tr("Localizable", "restore_unencrypted_file_cta_description_ios", fallback: "To import it, create a new Vault and navigate to **Settings → Import/Export**.")
  /// The Vault cannot be recovered from an unencrypted backup file.
  internal static let restoreUnencryptedFileDescription = T.tr("Localizable", "restore_unencrypted_file_description", fallback: "The Vault cannot be recovered from an unencrypted backup file.")
  /// Backup is unencrypted
  internal static let restoreUnencryptedFileTitle = T.tr("Localizable", "restore_unencrypted_file_title", fallback: "Backup is unencrypted")
  /// Scan the QR code on Recovery Key or enter Words manually.
  internal static let restoreUseRecoveryKeyDescription = T.tr("Localizable", "restore_use_recovery_key_description", fallback: "Scan the QR code on Recovery Key or enter Words manually.")
  /// Use Recovery Kit
  internal static let restoreUseRecoveryKeyTitle = T.tr("Localizable", "restore_use_recovery_key_title", fallback: "Use Recovery Kit")
  /// To recover or sync your 2FAS Pass Vault, select one of the available backup methods:
  internal static let restoreVaultSourceDescription = T.tr("Localizable", "restore_vault_source_description", fallback: "To recover or sync your 2FAS Pass Vault, select one of the available backup methods:")
  /// Local file
  internal static let restoreVaultSourceOptionFile = T.tr("Localizable", "restore_vault_source_option_file", fallback: "Local file")
  /// Import a backup file
  internal static let restoreVaultSourceOptionFileDescription = T.tr("Localizable", "restore_vault_source_option_file_description", fallback: "Import a backup file")
  /// Google Drive
  internal static let restoreVaultSourceOptionGoogleDrive = T.tr("Localizable", "restore_vault_source_option_google_drive", fallback: "Google Drive")
  /// Connect with your Google Drive
  internal static let restoreVaultSourceOptionGoogleDriveDescription = T.tr("Localizable", "restore_vault_source_option_google_drive_description", fallback: "Connect with your Google Drive")
  /// iCloud
  internal static let restoreVaultSourceOptionIcloud = T.tr("Localizable", "restore_vault_source_option_icloud", fallback: "iCloud")
  /// Restore backup from your iCloud
  internal static let restoreVaultSourceOptionIcloudDescription = T.tr("Localizable", "restore_vault_source_option_icloud_description", fallback: "Restore backup from your iCloud")
  /// WebDAV
  internal static let restoreVaultSourceOptionWebdav = T.tr("Localizable", "restore_vault_source_option_webdav", fallback: "WebDAV")
  /// Connect with your WebDAV server
  internal static let restoreVaultSourceOptionWebdavDescription = T.tr("Localizable", "restore_vault_source_option_webdav_description", fallback: "Connect with your WebDAV server")
  /// Select backup file
  internal static let restoreVaultSourceTitle = T.tr("Localizable", "restore_vault_source_title", fallback: "Select backup file")
  /// Enter your Master Password for this Vault
  internal static let restoreVaultVerifyMasterPasswordDescription = T.tr("Localizable", "restore_vault_verify_master_password_description", fallback: "Enter your Master Password for this Vault")
  /// Restore your 2FAS Pass Vault data from a WebDAV server
  internal static let restoreWebdavDescription = T.tr("Localizable", "restore_webdav_description", fallback: "Restore your 2FAS Pass Vault data from a WebDAV server")
  /// WebDAV
  internal static let restoreWebdavTitle = T.tr("Localizable", "restore_webdav_title", fallback: "WebDAV")
  /// Point your camera at the QR code found in your Decryption Kit.
  internal static let scanDecryptionKitDescription = T.tr("Localizable", "scan_decryption_kit_description", fallback: "Point your camera at the QR code found in your Decryption Kit.")
  /// Scan QR code
  internal static let scanDecryptionKitTitle = T.tr("Localizable", "scan_decryption_kit_title", fallback: "Scan QR code")
  /// Enable Biometrics
  internal static let securityBiometricsEnableCta = T.tr("Localizable", "security_biometrics_enable_cta", fallback: "Enable Biometrics")
  /// Master Password is required to enable biometrics.
  internal static let securityBiometricsEnableDescription = T.tr("Localizable", "security_biometrics_enable_description", fallback: "Master Password is required to enable biometrics.")
  /// Enable Biometrics
  internal static let securityBiometricsEnableTitle = T.tr("Localizable", "security_biometrics_enable_title", fallback: "Enable Biometrics")
  /// Authenticate
  internal static let securityDecryptionKitAccessCta = T.tr("Localizable", "security_decryption_kit_access_cta", fallback: "Authenticate")
  /// Master Password is required to access the Decryption Kit
  internal static let securityDecryptionKitAccessDescription = T.tr("Localizable", "security_decryption_kit_access_description", fallback: "Master Password is required to access the Decryption Kit")
  /// Access Decryption Kit
  internal static let securityDecryptionKitAccessTitle = T.tr("Localizable", "security_decryption_kit_access_title", fallback: "Access Decryption Kit")
  /// Authenticate
  internal static let securityLockoutSettingsCta = T.tr("Localizable", "security_lockout_settings_cta", fallback: "Authenticate")
  /// Authentication is required to change lockout settings
  internal static let securityLockoutSettingsDescription = T.tr("Localizable", "security_lockout_settings_description", fallback: "Authentication is required to change lockout settings")
  /// Change Lockout Settings
  internal static let securityLockoutSettingsTitle = T.tr("Localizable", "security_lockout_settings_title", fallback: "Change Lockout Settings")
  /// Enable Screen Capture
  internal static let securityScreenCaptureEnableCta = T.tr("Localizable", "security_screen_capture_enable_cta", fallback: "Enable Screen Capture")
  /// Authentication is required to enable Screen Capture
  internal static let securityScreenCaptureEnableDescription = T.tr("Localizable", "security_screen_capture_enable_description", fallback: "Authentication is required to enable Screen Capture")
  /// Enable Screen Capture
  internal static let securityScreenCaptureEnableTitle = T.tr("Localizable", "security_screen_capture_enable_title", fallback: "Enable Screen Capture")
  /// Security of your data
  internal static let securityTiersHelpLocalFirstSectionFigureTitle = T.tr("Localizable", "security_tiers_help_local_first_section_figure_title", fallback: "Security of your data")
  /// 2FAS Pass stores all your Items in an encrypted local Vault on your mobile device. Hackers can't breach users' security data as there is no single point of attack, and every user stores their data privately.
  internal static let securityTiersHelpLocalFirstSectionSubtitle = T.tr("Localizable", "security_tiers_help_local_first_section_subtitle", fallback: "2FAS Pass stores all your Items in an encrypted local Vault on your mobile device. Hackers can't breach users' security data as there is no single point of attack, and every user stores their data privately.")
  /// 1. Local-first approach
  internal static let securityTiersHelpLocalFirstSectionTitle = T.tr("Localizable", "security_tiers_help_local_first_section_title", fallback: "1. Local-first approach")
  /// 2FAS Pass provides an outstanding level of data security thanks to 3 core pillars:
  internal static let securityTiersHelpSubtitle = T.tr("Localizable", "security_tiers_help_subtitle", fallback: "2FAS Pass provides an outstanding level of data security thanks to 3 core pillars:")
  /// Items assigned to the Highly Secret Tier provide a higher security standard and require additional confirmation. Access through the Browser Extension or using Autofill must be confirmed in 2FAS Pass.
  internal static let securityTiersHelpTiersHighlySecretSubtitle = T.tr("Localizable", "security_tiers_help_tiers_highly_secret_subtitle", fallback: "Items assigned to the Highly Secret Tier provide a higher security standard and require additional confirmation. Access through the Browser Extension or using Autofill must be confirmed in 2FAS Pass.")
  /// Highly Secret
  internal static let securityTiersHelpTiersHighlySecretTitle = T.tr("Localizable", "security_tiers_help_tiers_highly_secret_title", fallback: "Highly Secret")
  /// When you enable ADP and iCloud sync, your data is encrypted twice — first with your E2EE and then with Apple's encryption keys. Even if someone gains access to your iCloud, they will only find fully encrypted E2EE data, keeping it secure.
  internal static let securityTiersHelpTiersLayersAdpSubtitle = T.tr("Localizable", "security_tiers_help_tiers_layers_adp_subtitle", fallback: "When you enable ADP and iCloud sync, your data is encrypted twice — first with your E2EE and then with Apple's encryption keys. Even if someone gains access to your iCloud, they will only find fully encrypted E2EE data, keeping it secure.")
  /// Apple Advanced Data Protection
  internal static let securityTiersHelpTiersLayersAdpTitle = T.tr("Localizable", "security_tiers_help_tiers_layers_adp_title", fallback: "Apple Advanced Data Protection")
  /// When setting up a new device, you'll need a 15-word recovery list to restore your SEED. It's securely stored in Apple's Secure Enclave — a dedicated, tamper-resistant chip - ensuring your encryption keys never leave your device.
  internal static let securityTiersHelpTiersLayersSecureEnclaveSubtitle = T.tr("Localizable", "security_tiers_help_tiers_layers_secure_enclave_subtitle", fallback: "When setting up a new device, you'll need a 15-word recovery list to restore your SEED. It's securely stored in Apple's Secure Enclave — a dedicated, tamper-resistant chip - ensuring your encryption keys never leave your device.")
  /// Apple Secure Enclave
  internal static let securityTiersHelpTiersLayersSecureEnclaveTitle = T.tr("Localizable", "security_tiers_help_tiers_layers_secure_enclave_title", fallback: "Apple Secure Enclave")
  /// Items assigned to the Secret Tier are stored securely on your mobile device. They are available in Autofill and the 2FAS Pass Browser Extension whenever you need them.
  internal static let securityTiersHelpTiersSecretSubtitle = T.tr("Localizable", "security_tiers_help_tiers_secret_subtitle", fallback: "Items assigned to the Secret Tier are stored securely on your mobile device. They are available in Autofill and the 2FAS Pass Browser Extension whenever you need them.")
  /// Secret
  internal static let securityTiersHelpTiersSecretTitle = T.tr("Localizable", "security_tiers_help_tiers_secret_title", fallback: "Secret")
  /// With Security Tiers, you decide how to use individual Items with Autofill and share them with the 2FAS Pass Browser Extension.
  internal static let securityTiersHelpTiersSectionSubtitle = T.tr("Localizable", "security_tiers_help_tiers_section_subtitle", fallback: "With Security Tiers, you decide how to use individual Items with Autofill and share them with the 2FAS Pass Browser Extension.")
  /// 2. Security Tiers
  internal static let securityTiersHelpTiersSectionTitle = T.tr("Localizable", "security_tiers_help_tiers_section_title", fallback: "2. Security Tiers")
  /// Items assigned to the Top Secret Tier are isolated and cannot be used with Autofill or 2FAS Pass Browser Extension. They must be entered manually.
  internal static let securityTiersHelpTiersTopSecretSubtitle = T.tr("Localizable", "security_tiers_help_tiers_top_secret_subtitle", fallback: "Items assigned to the Top Secret Tier are isolated and cannot be used with Autofill or 2FAS Pass Browser Extension. They must be entered manually.")
  /// How do we ensure data security?
  internal static let securityTiersHelpTitle = T.tr("Localizable", "security_tiers_help_title", fallback: "How do we ensure data security?")
  /// With Security Tiers, you decide how to use individual Items with Autofill and share them with the 2FAS Pass Browser Extension.
  internal static let securityTypeModalDescription = T.tr("Localizable", "security_type_modal_description", fallback: "With Security Tiers, you decide how to use individual Items with Autofill and share them with the 2FAS Pass Browser Extension.")
  /// Choose Security Tier
  internal static let securityTypeModalHeader = T.tr("Localizable", "security_type_modal_header", fallback: "Choose Security Tier")
  /// Changing the Master Password will update your Vault encryption, so you'll need to 
  internal static let setNewPasswordConfirmBodyPart1 = T.tr("Localizable", "set_new_password_confirm_body_part1", fallback: "Changing the Master Password will update your Vault encryption, so you'll need to ")
  /// Changing your Master Password will update your Vault encryption, and you'll need to **download a new Decryption Kit.**
  internal static let setNewPasswordConfirmBodyPart1Ios = T.tr("Localizable", "set_new_password_confirm_body_part1_ios", fallback: "Changing your Master Password will update your Vault encryption, and you'll need to **download a new Decryption Kit.**")
  /// download a new Decryption Kit.
  internal static let setNewPasswordConfirmBodyPart2Bold = T.tr("Localizable", "set_new_password_confirm_body_part2_bold", fallback: "download a new Decryption Kit.")
  /// If you use this Vault on other devices, Sync will be disabled, and you'll need to re-enable it using your new Master Password.
  internal static let setNewPasswordConfirmBodyPart2Ios = T.tr("Localizable", "set_new_password_confirm_body_part2_ios", fallback: "If you use this Vault on other devices, Sync will be disabled, and you'll need to re-enable it using your new Master Password.")
  /// 
  /// 
  /// If you use this Vault on other devices, Cloud Sync will be paused on them, and you'll need to 
  internal static let setNewPasswordConfirmBodyPart3 = T.tr("Localizable", "set_new_password_confirm_body_part3", fallback: "\n\nIf you use this Vault on other devices, Cloud Sync will be paused on them, and you'll need to ")
  /// re-enable it 
  internal static let setNewPasswordConfirmBodyPart4Bold = T.tr("Localizable", "set_new_password_confirm_body_part4_bold", fallback: "re-enable it ")
  /// with your new Master Password.
  internal static let setNewPasswordConfirmBodyPart5 = T.tr("Localizable", "set_new_password_confirm_body_part5", fallback: "with your new Master Password.")
  /// Confirm Password Change
  internal static let setNewPasswordConfirmTitle = T.tr("Localizable", "set_new_password_confirm_title", fallback: "Confirm Password Change")
  /// Please enter and confirm your new Master Password to complete the update.
  internal static let setNewPasswordScreenDescription = T.tr("Localizable", "set_new_password_screen_description", fallback: "Please enter and confirm your new Master Password to complete the update.")
  /// New Master Password
  internal static let setNewPasswordScreenTitle = T.tr("Localizable", "set_new_password_screen_title", fallback: "New Master Password")
  /// Master Password successfully changed
  internal static let setNewPasswordSuccessTitle = T.tr("Localizable", "set_new_password_success_title", fallback: "Master Password successfully changed")
  /// Get 2FAS Auth
  internal static let settings2fasGet = T.tr("Localizable", "settings_2fas_get", fallback: "Get 2FAS Auth")
  /// Open 2FAS Auth
  internal static let settings2fasOpen = T.tr("Localizable", "settings_2fas_open", fallback: "Open 2FAS Auth")
  /// About
  internal static let settingsAbout = T.tr("Localizable", "settings_about", fallback: "About")
  /// Keyboard inline suggestions
  internal static let settingsAutofillKeyboard = T.tr("Localizable", "settings_autofill_keyboard", fallback: "Keyboard inline suggestions")
  /// Display autofill suggestions in your keyboard (if supported).
  internal static let settingsAutofillKeyboardDescription = T.tr("Localizable", "settings_autofill_keyboard_description", fallback: "Display autofill suggestions in your keyboard (if supported).")
  /// Configure AutoFill: Settings -> Notifications -> 2FAS Pass
  internal static let settingsAutofillOpenSystemSettingsDescription = T.tr("Localizable", "settings_autofill_open_system_settings_description", fallback: "Configure AutoFill: Settings -> Notifications -> 2FAS Pass")
  /// Setup Autofill
  internal static let settingsAutofillService = T.tr("Localizable", "settings_autofill_service", fallback: "Setup Autofill")
  /// Select 2FAS Pass to automatically fill in Item details in other apps.
  internal static let settingsAutofillServiceDescription = T.tr("Localizable", "settings_autofill_service_description", fallback: "Select 2FAS Pass to automatically fill in Item details in other apps.")
  /// Set app as your AutoFill provider
  internal static let settingsAutofillToggle = T.tr("Localizable", "settings_autofill_toggle", fallback: "Set app as your AutoFill provider")
  /// Automatically fill in your information from the keyboard when you need it.
  internal static let settingsAutofillToggleDescription = T.tr("Localizable", "settings_autofill_toggle_description", fallback: "Automatically fill in your information from the keyboard when you need it.")
  /// Securely sync your 2FAS Pass Vault with iCloud or WebDAV to protect your data in case this device gets lost or damaged.
  internal static let settingsCloudSyncDescription = T.tr("Localizable", "settings_cloud_sync_description", fallback: "Securely sync your 2FAS Pass Vault with iCloud or WebDAV to protect your data in case this device gets lost or damaged.")
  /// iCloud Sync
  internal static let settingsCloudSyncIcloudLabel = T.tr("Localizable", "settings_cloud_sync_icloud_label", fallback: "iCloud Sync")
  /// Last successful synchronization: **%@**
  internal static func settingsCloudSyncLastSync(_ p1: Any) -> String {
    return T.tr("Localizable", "settings_cloud_sync_last_sync %@", String(describing: p1), fallback: "Last successful synchronization: **%@**")
  }
  /// Status: **%@**
  internal static func settingsCloudSyncStatus(_ p1: Any) -> String {
    return T.tr("Localizable", "settings_cloud_sync_status %@", String(describing: p1), fallback: "Status: **%@**")
  }
  /// Vault Sync
  internal static let settingsCloudSyncTitle = T.tr("Localizable", "settings_cloud_sync_title", fallback: "Vault Sync")
  /// WebDAV
  internal static let settingsCloudSyncWebdavLabel = T.tr("Localizable", "settings_cloud_sync_webdav_label", fallback: "WebDAV")
  /// About 2FAS Pass
  internal static let settingsEntryAbout = T.tr("Localizable", "settings_entry_about", fallback: "About 2FAS Pass")
  /// Access security
  internal static let settingsEntryAppAccess = T.tr("Localizable", "settings_entry_app_access", fallback: "Access security")
  /// Max failed attempts
  internal static let settingsEntryAppLockAttempts = T.tr("Localizable", "settings_entry_app_lock_attempts", fallback: "Max failed attempts")
  /// After this number of failed attempts, the application will be locked for 1 minute. It will increase progressively to 3 minutes, 5 minutes, 15 minutes, up to 1 hour.
  internal static let settingsEntryAppLockAttemptsDescription = T.tr("Localizable", "settings_entry_app_lock_attempts_description", fallback: "After this number of failed attempts, the application will be locked for 1 minute. It will increase progressively to 3 minutes, 5 minutes, 15 minutes, up to 1 hour.")
  /// Set the number of failed Master Password attempts that will lock the application for the specified time.
  internal static let settingsEntryAppLockAttemptsFooter = T.tr("Localizable", "settings_entry_app_lock_attempts_footer", fallback: "Set the number of failed Master Password attempts that will lock the application for the specified time.")
  /// App lockout time
  internal static let settingsEntryAppLockTime = T.tr("Localizable", "settings_entry_app_lock_time", fallback: "App lockout time")
  /// Set the duration after which the app will require the Master Password again.
  internal static let settingsEntryAppLockTimeDescription = T.tr("Localizable", "settings_entry_app_lock_time_description", fallback: "Set the duration after which the app will require the Master Password again.")
  /// Autofill
  internal static let settingsEntryAutofill = T.tr("Localizable", "settings_entry_autofill", fallback: "Autofill")
  /// Enable autofill to automatically fill in Item details.
  internal static let settingsEntryAutofillDescription = T.tr("Localizable", "settings_entry_autofill_description", fallback: "Enable autofill to automatically fill in Item details.")
  /// Autofill lockout time
  internal static let settingsEntryAutofillLockTime = T.tr("Localizable", "settings_entry_autofill_lock_time", fallback: "Autofill lockout time")
  /// Set the duration after which the autofill service will require the Master Password again. This is only relevant for services assigned to the Secret Tier.
  internal static let settingsEntryAutofillLockTimeDescription = T.tr("Localizable", "settings_entry_autofill_lock_time_description", fallback: "Set the duration after which the autofill service will require the Master Password again. This is only relevant for services assigned to the Secret Tier.")
  /// Biometrics
  internal static let settingsEntryBiometrics = T.tr("Localizable", "settings_entry_biometrics", fallback: "Biometrics")
  /// Use your biometric data to unlock the app instead of using a Master Password.
  internal static let settingsEntryBiometricsDescription = T.tr("Localizable", "settings_entry_biometrics_description", fallback: "Use your biometric data to unlock the app instead of using a Master Password.")
  /// Biometric authentication is not available.
  internal static let settingsEntryBiometricsNotAvailable = T.tr("Localizable", "settings_entry_biometrics_not_available", fallback: "Biometric authentication is not available.")
  /// Unlock app with Biometrics
  internal static let settingsEntryBiometricsToggle = T.tr("Localizable", "settings_entry_biometrics_toggle", fallback: "Unlock app with Biometrics")
  /// Change Master Password
  internal static let settingsEntryChangePassword = T.tr("Localizable", "settings_entry_change_password", fallback: "Change Master Password")
  /// Sync
  internal static let settingsEntryCloudSync = T.tr("Localizable", "settings_entry_cloud_sync", fallback: "Sync")
  /// Automatically back up and sync your data across devices.
  internal static let settingsEntryCloudSyncDescription = T.tr("Localizable", "settings_entry_cloud_sync_description", fallback: "Automatically back up and sync your data across devices.")
  /// Select provider
  internal static let settingsEntryCloudSyncProvider = T.tr("Localizable", "settings_entry_cloud_sync_provider", fallback: "Select provider")
  /// Convenience
  internal static let settingsEntryConvenience = T.tr("Localizable", "settings_entry_convenience", fallback: "Convenience")
  /// Customization
  internal static let settingsEntryCustomization = T.tr("Localizable", "settings_entry_customization", fallback: "Customization")
  /// Tailor the app's appearance and features.
  internal static let settingsEntryCustomizationDescription = T.tr("Localizable", "settings_entry_customization_description", fallback: "Tailor the app's appearance and features.")
  /// Default Security
  internal static let settingsEntryDataAccess = T.tr("Localizable", "settings_entry_data_access", fallback: "Default Security")
  /// Decryption Kit
  internal static let settingsEntryDecryptionKit = T.tr("Localizable", "settings_entry_decryption_kit", fallback: "Decryption Kit")
  /// Download your Decryption Kit again if you have lost it.
  internal static let settingsEntryDecryptionKitDescription = T.tr("Localizable", "settings_entry_decryption_kit_description", fallback: "Download your Decryption Kit again if you have lost it.")
  /// Device nickname
  internal static let settingsEntryDeviceNickname = T.tr("Localizable", "settings_entry_device_nickname", fallback: "Device nickname")
  /// Set the nickname used to identify this device.
  internal static let settingsEntryDeviceNicknameDescription = T.tr("Localizable", "settings_entry_device_nickname_description", fallback: "Set the nickname used to identify this device.")
  /// Our Discord Community
  internal static let settingsEntryDiscord = T.tr("Localizable", "settings_entry_discord", fallback: "Our Discord Community")
  /// Dynamic Theme
  internal static let settingsEntryDynamicColors = T.tr("Localizable", "settings_entry_dynamic_colors", fallback: "Dynamic Theme")
  /// Change the app theme based on your wallpaper for a more dynamic experience.
  internal static let settingsEntryDynamicColorsDescription = T.tr("Localizable", "settings_entry_dynamic_colors_description", fallback: "Change the app theme based on your wallpaper for a more dynamic experience.")
  /// Export to file
  internal static let settingsEntryExport2pass = T.tr("Localizable", "settings_entry_export_2pass", fallback: "Export to file")
  /// Google Drive
  internal static let settingsEntryGoogleDrive = T.tr("Localizable", "settings_entry_google_drive", fallback: "Google Drive")
  /// Google Drive sync
  internal static let settingsEntryGoogleDriveSync = T.tr("Localizable", "settings_entry_google_drive_sync", fallback: "Google Drive sync")
  /// Automatically back up and sync your data across devices.
  internal static let settingsEntryGoogleDriveSyncDescription = T.tr("Localizable", "settings_entry_google_drive_sync_description", fallback: "Automatically back up and sync your data across devices.")
  /// Backup file is stored in a hidden folder on your Google Drive. This folder is only accessible by the 2FAS Pass app. Backup file is encrypted with your Master Password.
  internal static let settingsEntryGoogleDriveSyncExplanation = T.tr("Localizable", "settings_entry_google_drive_sync_explanation", fallback: "Backup file is stored in a hidden folder on your Google Drive. This folder is only accessible by the 2FAS Pass app. Backup file is encrypted with your Master Password.")
  /// Help Center
  internal static let settingsEntryHelpCenter = T.tr("Localizable", "settings_entry_help_center", fallback: "Help Center")
  /// Import file
  internal static let settingsEntryImport2pass = T.tr("Localizable", "settings_entry_import_2pass", fallback: "Import file")
  /// Import / Export
  internal static let settingsEntryImportExport = T.tr("Localizable", "settings_entry_import_export", fallback: "Import / Export")
  /// Local backup
  internal static let settingsEntryImportExport2pass = T.tr("Localizable", "settings_entry_import_export_2pass", fallback: "Local backup")
  /// Move your data between devices.
  internal static let settingsEntryImportExportDescription = T.tr("Localizable", "settings_entry_import_export_description", fallback: "Move your data between devices.")
  /// Apps
  internal static let settingsEntryImportOtherApps = T.tr("Localizable", "settings_entry_import_other_apps", fallback: "Apps")
  /// Trusted Extensions
  internal static let settingsEntryKnownBrowsers = T.tr("Localizable", "settings_entry_known_browsers", fallback: "Trusted Extensions")
  /// Manage trusted browser extensions.
  internal static let settingsEntryKnownBrowsersDescription = T.tr("Localizable", "settings_entry_known_browsers_description", fallback: "Manage trusted browser extensions.")
  /// Lockout settings
  internal static let settingsEntryLockoutSettings = T.tr("Localizable", "settings_entry_lockout_settings", fallback: "Lockout settings")
  /// Manage the app's lockouts settings.
  internal static let settingsEntryLockoutSettingsDescription = T.tr("Localizable", "settings_entry_lockout_settings_description", fallback: "Manage the app's lockouts settings.")
  /// Default action on tap
  internal static let settingsEntryLoginClickAction = T.tr("Localizable", "settings_entry_login_click_action", fallback: "Default action on tap")
  /// Select what action to perform when you tap an Item.
  internal static let settingsEntryLoginClickActionDescription = T.tr("Localizable", "settings_entry_login_click_action_description", fallback: "Select what action to perform when you tap an Item.")
  /// Security Tier
  internal static let settingsEntryProtectionLevel = T.tr("Localizable", "settings_entry_protection_level", fallback: "Security Tier")
  /// Top Secret
  internal static let settingsEntryProtectionLevel0 = T.tr("Localizable", "settings_entry_protection_level0", fallback: "Top Secret")
  /// **Secret** + Items are isolated in the mobile application.
  /// Autofill has no access to the Item.
  /// Browser Extension has no access to the Item.
  internal static let settingsEntryProtectionLevel0Description = T.tr("Localizable", "settings_entry_protection_level0_description", fallback: "**Secret** + Items are isolated in the mobile application.\nAutofill has no access to the Item.\nBrowser Extension has no access to the Item.")
  /// Highly Secret
  internal static let settingsEntryProtectionLevel1 = T.tr("Localizable", "settings_entry_protection_level1", fallback: "Highly Secret")
  /// **Secret** + Additional confirmation required.
  /// Autofill requires app confirmation.
  /// Browser Extension requires app confirmation.
  internal static let settingsEntryProtectionLevel1Description = T.tr("Localizable", "settings_entry_protection_level1_description", fallback: "**Secret** + Additional confirmation required.\nAutofill requires app confirmation.\nBrowser Extension requires app confirmation.")
  /// Secret
  internal static let settingsEntryProtectionLevel2 = T.tr("Localizable", "settings_entry_protection_level2", fallback: "Secret")
  /// **Stored securely on your mobile device.**
  /// Autofill requires system confirmation.
  /// Browser Extension can use the Item when needed.
  internal static let settingsEntryProtectionLevel2Description = T.tr("Localizable", "settings_entry_protection_level2_description", fallback: "**Stored securely on your mobile device.**\nAutofill requires system confirmation.\nBrowser Extension can use the Item when needed.")
  /// With Security Tiers, you decide how to use individual Items with Autofill and share them with the 2FAS Pass Browser Extension.
  internal static let settingsEntryProtectionLevelDescription = T.tr("Localizable", "settings_entry_protection_level_description", fallback: "With Security Tiers, you decide how to use individual Items with Autofill and share them with the 2FAS Pass Browser Extension.")
  /// Push Notifications
  internal static let settingsEntryPushNotifications = T.tr("Localizable", "settings_entry_push_notifications", fallback: "Push Notifications")
  /// Customize notifications to stay updated on app activity and security.
  internal static let settingsEntryPushNotificationsDescription = T.tr("Localizable", "settings_entry_push_notifications_description", fallback: "Customize notifications to stay updated on app activity and security.")
  /// Screen Capture
  internal static let settingsEntryScreenCapture = T.tr("Localizable", "settings_entry_screen_capture", fallback: "Screen Capture")
  /// Allow screenshots and screen recordings of the app for 5 minutes.
  internal static let settingsEntryScreenCaptureDescription = T.tr("Localizable", "settings_entry_screen_capture_description", fallback: "Allow screenshots and screen recordings of the app for 5 minutes.")
  /// Are you sure? This option lets you screenshot and record anything within the app. However, it will also enable any external attempts to capture screens in the app. To ensure safety, this option will automatically turn off after 5 minutes.
  internal static let settingsEntryScreenshotsConfirmDescription = T.tr("Localizable", "settings_entry_screenshots_confirm_description", fallback: "Are you sure? This option lets you screenshot and record anything within the app. However, it will also enable any external attempts to capture screens in the app. To ensure safety, this option will automatically turn off after 5 minutes.")
  /// Allow Screen Capture?
  internal static let settingsEntryScreenshotsConfirmTitle = T.tr("Localizable", "settings_entry_screenshots_confirm_title", fallback: "Allow Screen Capture?")
  /// Security
  internal static let settingsEntrySecurity = T.tr("Localizable", "settings_entry_security", fallback: "Security")
  /// Control your app security and privacy settings.
  internal static let settingsEntrySecurityDescription = T.tr("Localizable", "settings_entry_security_description", fallback: "Control your app security and privacy settings.")
  /// Subscription
  internal static let settingsEntrySubscription = T.tr("Localizable", "settings_entry_subscription", fallback: "Subscription")
  /// Account
  internal static let settingsEntrySyncAccount = T.tr("Localizable", "settings_entry_sync_account", fallback: "Account")
  /// Sync Info
  internal static let settingsEntrySyncInfo = T.tr("Localizable", "settings_entry_sync_info", fallback: "Sync Info")
  /// Last synchronization
  internal static let settingsEntrySyncLast = T.tr("Localizable", "settings_entry_sync_last", fallback: "Last synchronization")
  /// Theme
  internal static let settingsEntryTheme = T.tr("Localizable", "settings_entry_theme", fallback: "Theme")
  /// Transfer from Other Apps
  internal static let settingsEntryTransferFromOtherApps = T.tr("Localizable", "settings_entry_transfer_from_other_apps", fallback: "Transfer from Other Apps")
  /// Easily transfer your data from another password manager and quickly set it up in 2FAS Pass.
  internal static let settingsEntryTransferFromOtherAppsDescription = T.tr("Localizable", "settings_entry_transfer_from_other_apps_description", fallback: "Easily transfer your data from another password manager and quickly set it up in 2FAS Pass.")
  /// Removed Items
  internal static let settingsEntryTrash = T.tr("Localizable", "settings_entry_trash", fallback: "Removed Items")
  /// Recover or permanently delete Items you've removed from the app.
  internal static let settingsEntryTrashDescription = T.tr("Localizable", "settings_entry_trash_description", fallback: "Recover or permanently delete Items you've removed from the app.")
  /// WebDAV
  internal static let settingsEntryWebdav = T.tr("Localizable", "settings_entry_webdav", fallback: "WebDAV")
  /// More
  internal static let settingsHeaderAbout = T.tr("Localizable", "settings_header_about", fallback: "More")
  /// Backup and Transfer
  internal static let settingsHeaderBackup = T.tr("Localizable", "settings_header_backup", fallback: "Backup and Transfer")
  /// Browser Extension
  internal static let settingsHeaderBrowserExtension = T.tr("Localizable", "settings_header_browser_extension", fallback: "Browser Extension")
  /// Mobile App
  internal static let settingsHeaderMobileApp = T.tr("Localizable", "settings_header_mobile_app", fallback: "Mobile App")
  /// Preferences
  internal static let settingsHeaderPreferences = T.tr("Localizable", "settings_header_preferences", fallback: "Preferences")
  /// Choose Security Tier
  internal static let settingsHeaderProtectionLevel = T.tr("Localizable", "settings_header_protection_level", fallback: "Choose Security Tier")
  /// Manage 2FA Tokens
  internal static let settingsManageTokensTitle = T.tr("Localizable", "settings_manage_tokens_title", fallback: "Manage 2FA Tokens")
  /// How does 2FAS ensure data security?
  internal static let settingsProtectionLevelHelp = T.tr("Localizable", "settings_protection_level_help", fallback: "How does 2FAS ensure data security?")
  /// Enable
  internal static let settingsPushNotificationsEnableCta = T.tr("Localizable", "settings_push_notifications_enable_cta", fallback: "Enable")
  /// Configure Push notifications: Settings -> Notifications -> 2FAS Pass
  internal static let settingsPushNotificationsOpenSystemSettingsDescription = T.tr("Localizable", "settings_push_notifications_open_system_settings_description", fallback: "Configure Push notifications: Settings -> Notifications -> 2FAS Pass")
  /// Status
  internal static let settingsPushNotificationsStatusLabel = T.tr("Localizable", "settings_push_notifications_status_label", fallback: "Status")
  /// Settings
  internal static let settingsTitle = T.tr("Localizable", "settings_title", fallback: "Settings")
  /// Check this out!
  internal static let shareLinkMessage = T.tr("Localizable", "share_link_message", fallback: "Check this out!")
  /// Amazing app!
  internal static let shareLinkSubject = T.tr("Localizable", "share_link_subject", fallback: "Amazing app!")
  /// Free Plan
  internal static let subscriptionFreePlan = T.tr("Localizable", "subscription_free_plan", fallback: "Free Plan")
  /// Unlimited
  internal static let subscriptionUnlimitedPlan = T.tr("Localizable", "subscription_unlimited_plan", fallback: "Unlimited")
  /// Checking ...
  internal static let syncChecking = T.tr("Localizable", "sync_checking", fallback: "Checking ...")
  /// Sync is currently disabled
  internal static let syncDisabled = T.tr("Localizable", "sync_disabled", fallback: "Sync is currently disabled")
  /// iCloud account is disabled. Check app settings in system Settings
  internal static let syncErrorIcloudDisabled = T.tr("Localizable", "sync_error_icloud_disabled", fallback: "iCloud account is disabled. Check app settings in system Settings")
  /// iCloud error
  internal static let syncErrorIcloudError = T.tr("Localizable", "sync_error_icloud_error", fallback: "iCloud error")
  /// Access to iCloud account is restricted
  internal static let syncErrorIcloudErrorAccessRestricted = T.tr("Localizable", "sync_error_icloud_error_access_restricted", fallback: "Access to iCloud account is restricted")
  /// iCloud error: %@
  internal static func syncErrorIcloudErrorDetails(_ p1: Any) -> String {
    return T.tr("Localizable", "sync_error_icloud_error_details", String(describing: p1), fallback: "iCloud error: %@")
  }
  /// iCloud Vault was created with diffrent encryption. Delete the app and restore using Recover Kit
  internal static let syncErrorIcloudErrorDiffrentEncryption = T.tr("Localizable", "sync_error_icloud_error_diffrent_encryption", fallback: "iCloud Vault was created with diffrent encryption. Delete the app and restore using Recover Kit")
  /// iCloud Vault is in newer version. Update the app
  internal static let syncErrorIcloudErrorNewerVersion = T.tr("Localizable", "sync_error_icloud_error_newer_version", fallback: "iCloud Vault is in newer version. Update the app")
  /// No iCloud account was setup
  internal static let syncErrorIcloudErrorNoAccount = T.tr("Localizable", "sync_error_icloud_error_no_account", fallback: "No iCloud account was setup")
  /// There was a problem with iCloud sync. Try rebooting the device
  internal static let syncErrorIcloudErrorReboot = T.tr("Localizable", "sync_error_icloud_error_reboot", fallback: "There was a problem with iCloud sync. Try rebooting the device")
  /// Check if you're correctly logged into iCloud
  internal static let syncErrorIcloudErrorUserLoggedIn = T.tr("Localizable", "sync_error_icloud_error_user_logged_in", fallback: "Check if you're correctly logged into iCloud")
  /// iCloud account is over quota
  internal static let syncErrorIcloudQuota = T.tr("Localizable", "sync_error_icloud_quota", fallback: "iCloud account is over quota")
  /// Vault in iCloud has diffrent password or encryption. Restore from iCloud to use this Vault
  internal static let syncErrorIcloudVaultEncryptionRestore = T.tr("Localizable", "sync_error_icloud_vault_encryption_restore", fallback: "Vault in iCloud has diffrent password or encryption. Restore from iCloud to use this Vault")
  /// Sync is not available
  internal static let syncNotAvailable = T.tr("Localizable", "sync_not_available", fallback: "Sync is not available")
  /// Forbidden
  internal static let syncStatusErrorForbidden = T.tr("Localizable", "sync_status_error_forbidden", fallback: "Forbidden")
  /// There was an error. Please try again. Error: %@
  internal static func syncStatusErrorGeneralReason(_ p1: Any) -> String {
    return T.tr("Localizable", "sync_status_error_general_reason", String(describing: p1), fallback: "There was an error. Please try again. Error: %@")
  }
  /// Incorrect URL. Check the path and try again
  internal static let syncStatusErrorIncorrectUrl = T.tr("Localizable", "sync_status_error_incorrect_url", fallback: "Incorrect URL. Check the path and try again")
  /// Premium plan required
  internal static let syncStatusErrorLimitDevicesReached = T.tr("Localizable", "sync_status_error_limit_devices_reached", fallback: "Premium plan required")
  /// Method Not Allowed
  internal static let syncStatusErrorMethodNotAllowed = T.tr("Localizable", "sync_status_error_method_not_allowed", fallback: "Method Not Allowed")
  /// A newer version of the app is requried to access the backup file
  internal static let syncStatusErrorNewerVersionNeeded = T.tr("Localizable", "sync_status_error_newer_version_needed", fallback: "A newer version of the app is requried to access the backup file")
  /// Newer version needed
  internal static let syncStatusErrorNewerVersionNeededTitle = T.tr("Localizable", "sync_status_error_newer_version_needed_title", fallback: "Newer version needed")
  /// Server error: Method not allowed. Ensure you're connecting to WebDAV server"
  internal static let syncStatusErrorNoWebDavServer = T.tr("Localizable", "sync_status_error_no_web_dav_server", fallback: "Server error: Method not allowed. Ensure you're connecting to WebDAV server\"")
  /// User is not authorized to access this path
  internal static let syncStatusErrorNotAuthorized = T.tr("Localizable", "sync_status_error_not_authorized", fallback: "User is not authorized to access this path")
  /// Not configured
  internal static let syncStatusErrorNotConfigured = T.tr("Localizable", "sync_status_error_not_configured", fallback: "Not configured")
  /// Master Password was changed. To access this vault use Restore and Recovery Kit.
  internal static let syncStatusErrorPasswordChanged = T.tr("Localizable", "sync_status_error_password_changed", fallback: "Master Password was changed. To access this vault use Restore and Recovery Kit.")
  /// SSL error
  internal static let syncStatusErrorSslError = T.tr("Localizable", "sync_status_error_ssl_error", fallback: "SSL error")
  /// TLS certificate validation failed
  internal static let syncStatusErrorTlsCertFailed = T.tr("Localizable", "sync_status_error_tls_cert_failed", fallback: "TLS certificate validation failed")
  /// Unauthorized
  internal static let syncStatusErrorUnauthorized = T.tr("Localizable", "sync_status_error_unauthorized", fallback: "Unauthorized")
  /// User is forbidden to access this path
  internal static let syncStatusErrorUserIsForbidden = T.tr("Localizable", "sync_status_error_user_is_forbidden", fallback: "User is forbidden to access this path")
  /// Idle
  internal static let syncStatusIdle = T.tr("Localizable", "sync_status_idle", fallback: "Idle")
  /// Retry
  internal static let syncStatusRetry = T.tr("Localizable", "sync_status_retry", fallback: "Retry")
  /// Retrying the connection
  internal static let syncStatusRetrying = T.tr("Localizable", "sync_status_retrying", fallback: "Retrying the connection")
  /// Retrying the connection: %@
  internal static func syncStatusRetryingDetails(_ p1: Any) -> String {
    return T.tr("Localizable", "sync_status_retrying_details", String(describing: p1), fallback: "Retrying the connection: %@")
  }
  /// Synced
  internal static let syncStatusSynced = T.tr("Localizable", "sync_status_synced", fallback: "Synced")
  /// Syncing...
  internal static let syncStatusSyncing = T.tr("Localizable", "sync_status_syncing", fallback: "Syncing...")
  /// Synced
  internal static let syncSynced = T.tr("Localizable", "sync_synced", fallback: "Synced")
  /// Syncing ...
  internal static let syncSyncing = T.tr("Localizable", "sync_syncing", fallback: "Syncing ...")
  /// Password copied
  internal static let toastPasswordCopied = T.tr("Localizable", "toast_password_copied", fallback: "Password copied")
  /// Username copied
  internal static let toastUsernameCopied = T.tr("Localizable", "toast_username copied", fallback: "Username copied")
  /// Passwords transferred
  internal static let transferFileSummaryCounterDescription = T.tr("Localizable", "transfer_file_summary_counter_description", fallback: "Passwords transferred")
  /// Proceed
  internal static let transferFileSummaryCta = T.tr("Localizable", "transfer_file_summary_cta", fallback: "Proceed")
  /// This file allows you to transfer
  internal static let transferFileSummaryDescription = T.tr("Localizable", "transfer_file_summary_description", fallback: "This file allows you to transfer")
  /// Application couldn’t import your 2FAS Pass Items. Please try again.
  internal static let transferImportingFailureDescription = T.tr("Localizable", "transfer_importing_failure_description", fallback: "Application couldn’t import your 2FAS Pass Items. Please try again.")
  /// Import failed
  internal static let transferImportingFailureTitle = T.tr("Localizable", "transfer_importing_failure_title", fallback: "Import failed")
  /// Importing...
  internal static let transferImportingFileText = T.tr("Localizable", "transfer_importing_file_text", fallback: "Importing...")
  /// Your 2FAS Pass Items have been successfully imported to Vault.
  internal static let transferImportingSuccessDescription = T.tr("Localizable", "transfer_importing_success_description", fallback: "Your 2FAS Pass Items have been successfully imported to Vault.")
  /// Imported successfully
  internal static let transferImportingSuccessTitle = T.tr("Localizable", "transfer_importing_success_title", fallback: "Imported successfully")
  /// Open **System settings** on your mobile device.
  /// 
  /// Go to **Apps** and select **Safari**.
  /// 
  /// Scroll down to **History and Website Data** and tap **Export**.
  /// 
  /// Make sure that only **Passwords** are selected and tap **Save to Downloads**.
  /// 
  /// Find the **Safari Export** ZIP file in Downloads.
  /// 
  /// Copy this ZIP file to this device and tap **Upload ZIP file** below. 
  internal static let transferInstructionsApplePasswordsMobile = T.tr("Localizable", "transfer_instructions_apple_passwords_mobile", fallback: "Open **System settings** on your mobile device.\n\nGo to **Apps** and select **Safari**.\n\nScroll down to **History and Website Data** and tap **Export**.\n\nMake sure that only **Passwords** are selected and tap **Save to Downloads**.\n\nFind the **Safari Export** ZIP file in Downloads.\n\nCopy this ZIP file to this device and tap **Upload ZIP file** below. ")
  /// Open the **Passwords** app on your Mac.
  /// 
  /// Click **File** on your menu bar.
  /// 
  /// Select **Export All/Selected Passwords to File**.
  /// 
  /// Click **Export Passwords**, choose the location and click **Save**.
  /// 
  /// Find the **Passwords** file saved in your download location.
  /// 
  /// Copy it to this device and tap **Upload CSV file** below.
  internal static let transferInstructionsApplePasswordsPc = T.tr("Localizable", "transfer_instructions_apple_passwords_pc", fallback: "Open the **Passwords** app on your Mac.\n\nClick **File** on your menu bar.\n\nSelect **Export All/Selected Passwords to File**.\n\nClick **Export Passwords**, choose the location and click **Save**.\n\nFind the **Passwords** file saved in your download location.\n\nCopy it to this device and tap **Upload CSV file** below.")
  /// Open Bitwarden and go to **Settings** (gear icon).
  /// 
  /// Go to **Tools/Vault**, then select **Export Vault**.
  /// 
  /// Choose **.JSON** as the file format and select **Export Vault**.
  /// 
  /// Copy the exported file to this device and tap **Upload JSON file** below.
  internal static let transferInstructionsBitwarden = T.tr("Localizable", "transfer_instructions_bitwarden", fallback: "Open Bitwarden and go to **Settings** (gear icon).\n\nGo to **Tools/Vault**, then select **Export Vault**.\n\nChoose **.JSON** as the file format and select **Export Vault**.\n\nCopy the exported file to this device and tap **Upload JSON file** below.")
  /// Open Google Chrome on your PC
  /// 
  /// Select your **Profile Icon** at the top right, then select **Passwords**.
  /// 
  /// Select **Settings** and **Download file**.
  /// 
  /// Copy the exported file to this device and tap **Upload CSV file** below. 
  internal static let transferInstructionsChrome = T.tr("Localizable", "transfer_instructions_chrome", fallback: "Open Google Chrome on your PC\n\nSelect your **Profile Icon** at the top right, then select **Passwords**.\n\nSelect **Settings** and **Download file**.\n\nCopy the exported file to this device and tap **Upload CSV file** below. ")
  /// Upload CSV file
  internal static let transferInstructionsCtaCsv = T.tr("Localizable", "transfer_instructions_cta_csv", fallback: "Upload CSV file")
  /// Upload file
  internal static let transferInstructionsCtaGeneric = T.tr("Localizable", "transfer_instructions_cta_generic", fallback: "Upload file")
  /// Upload JSON file
  internal static let transferInstructionsCtaJson = T.tr("Localizable", "transfer_instructions_cta_json", fallback: "Upload JSON file")
  /// Upload ZIP file
  internal static let transferInstructionsCtaZip = T.tr("Localizable", "transfer_instructions_cta_zip", fallback: "Upload ZIP file")
  /// Open Dashlane on your mobile phone.
  /// 
  /// Go to **Settings** and select **General**.
  /// 
  /// Select **Export data to CSV**, then confirm the export to a folder.
  /// 
  /// Select the CSV file labelled as **credentials** in the created folder.
  /// 
  /// Copy the **credentials** file to this device and tap **Upload CSV file** below.
  internal static let transferInstructionsDashlaneMobile = T.tr("Localizable", "transfer_instructions_dashlane_mobile", fallback: "Open Dashlane on your mobile phone.\n\nGo to **Settings** and select **General**.\n\nSelect **Export data to CSV**, then confirm the export to a folder.\n\nSelect the CSV file labelled as **credentials** in the created folder.\n\nCopy the **credentials** file to this device and tap **Upload CSV file** below.")
  /// Open Dashlane on your browser.
  /// 
  /// Expand the **My account** menu and select **Settings**.
  /// 
  /// Select **Export data** and **Export to CSV**.
  /// 
  /// Enter your Master Password, select **Unlock** and **Continue**.
  /// 
  /// Find the ZIP file saved in your default download location.
  /// 
  /// Copy this ZIP file to this device and tap **Upload ZIP file** below.
  internal static let transferInstructionsDashlanePc = T.tr("Localizable", "transfer_instructions_dashlane_pc", fallback: "Open Dashlane on your browser.\n\nExpand the **My account** menu and select **Settings**.\n\nSelect **Export data** and **Export to CSV**.\n\nEnter your Master Password, select **Unlock** and **Continue**.\n\nFind the ZIP file saved in your default download location.\n\nCopy this ZIP file to this device and tap **Upload ZIP file** below.")
  /// Transfer from %@
  internal static func transferInstructionsHeader(_ p1: Any) -> String {
    return T.tr("Localizable", "transfer_instructions_header %@", String(describing: p1), fallback: "Transfer from %@")
  }
  /// Log in to LastPass on your browser and go to **Advanced Options**.
  /// 
  /// Under **Manage Your Vault**, select **Export**. This will send you a verification email.
  /// 
  /// Open the received mail and select **Continue export**.
  /// 
  /// Back in the export window, enter your Master Password and save the CSV file.
  /// 
  /// Copy the exported file to this device and tap **Upload CSV file** below. 
  internal static let transferInstructionsLastpass = T.tr("Localizable", "transfer_instructions_lastpass", fallback: "Log in to LastPass on your browser and go to **Advanced Options**.\n\nUnder **Manage Your Vault**, select **Export**. This will send you a verification email.\n\nOpen the received mail and select **Continue export**.\n\nBack in the export window, enter your Master Password and save the CSV file.\n\nCopy the exported file to this device and tap **Upload CSV file** below. ")
  /// Open 1Password on your PC.
  /// 
  /// Click the three dots at the top of the side bar, select **Export** and choose the account you want to export, (on Mac select a specific Vault).
  /// 
  /// Enter your account password.
  /// 
  /// Choose the **CSV format** and select **Export data**.
  /// 
  /// Copy the exported file to this device and tap **Upload CSV file** below.
  internal static let transferInstructionsOnepassword = T.tr("Localizable", "transfer_instructions_onepassword", fallback: "Open 1Password on your PC.\n\nClick the three dots at the top of the side bar, select **Export** and choose the account you want to export, (on Mac select a specific Vault).\n\nEnter your account password.\n\nChoose the **CSV format** and select **Export data**.\n\nCopy the exported file to this device and tap **Upload CSV file** below.")
  /// Open Proton Pass via their browser extension, web app or Windows app.
  /// 
  /// Click the **Proton Pass Logo** and select **Settings**.
  /// 
  /// In the Settings menu, select **Export**.
  /// 
  /// Choose the **CSV format** and select **Export**.
  /// 
  /// Find the CSV file saved in your default download location.
  /// 
  /// Copy this file to this device and tap **Upload CSV file** below.
  internal static let transferInstructionsProtonpass = T.tr("Localizable", "transfer_instructions_protonpass", fallback: "Open Proton Pass via their browser extension, web app or Windows app.\n\nClick the **Proton Pass Logo** and select **Settings**.\n\nIn the Settings menu, select **Export**.\n\nChoose the **CSV format** and select **Export**.\n\nFind the CSV file saved in your default download location.\n\nCopy this file to this device and tap **Upload CSV file** below.")
  /// Please follow the instructions if you would like to import passwords from other applications into 2FAS Pass.
  /// 
  /// All product names, logos, and brands are the property of their respective owners. Use of these names does not imply any affiliation with or endorsement by them.
  internal static let transferServicesListFooter = T.tr("Localizable", "transfer_services_list_footer", fallback: "Please follow the instructions if you would like to import passwords from other applications into 2FAS Pass.\n\nAll product names, logos, and brands are the property of their respective owners. Use of these names does not imply any affiliation with or endorsement by them.")
  /// Import Instructions
  internal static let transferServicesListHeader = T.tr("Localizable", "transfer_services_list_header", fallback: "Import Instructions")
  /// Are you sure you want to permanently delete this Item? This cannot be undone!
  internal static let trashDeleteConfirmBodyIos = T.tr("Localizable", "trash_delete_confirm_body_ios", fallback: "Are you sure you want to permanently delete this Item? This cannot be undone!")
  /// Delete Item?
  internal static let trashDeleteConfirmTitleIos = T.tr("Localizable", "trash_delete_confirm_title_ios", fallback: "Delete Item?")
  /// Deleted: %@
  internal static func trashDeletedAt(_ p1: Any) -> String {
    return T.tr("Localizable", "trash_deleted_at %@", String(describing: p1), fallback: "Deleted: %@")
  }
  /// Trash is empty
  internal static let trashEmpty = T.tr("Localizable", "trash_empty", fallback: "Trash is empty")
  /// Delete
  internal static let trashRemovePermanently = T.tr("Localizable", "trash_remove_permanently", fallback: "Delete")
  /// Restore
  internal static let trashRestore = T.tr("Localizable", "trash_restore", fallback: "Restore")
  /// Matching Rule
  internal static let uriSettingsMatchingRuleHeader = T.tr("Localizable", "uri_settings_matching_rule_header", fallback: "Matching Rule")
  /// Each website or app address (URI) saved in your Item can have a specific matching rule. This rule determines when 2FAS Pass will suggest your Item information based on how closely the current address matches the saved URI.
  internal static let uriSettingsModalDescription = T.tr("Localizable", "uri_settings_modal_description", fallback: "Each website or app address (URI) saved in your Item can have a specific matching rule. This rule determines when 2FAS Pass will suggest your Item information based on how closely the current address matches the saved URI.")
  /// URL
  internal static let uriSettingsModalHeader = T.tr("Localizable", "uri_settings_modal_header", fallback: "URL")
  /// Decrypting ...
  internal static let vaultRecoveryDecrypting = T.tr("Localizable", "vault_recovery_decrypting", fallback: "Decrypting ...")
  /// File is corrupted and can't be decrypted.
  internal static let vaultRecoveryErrorFileCorrupted = T.tr("Localizable", "vault_recovery_error_file_corrupted", fallback: "File is corrupted and can't be decrypted.")
  /// There was an error while accessing the file from Gallery. Ensure you have an internet connection and try again.
  internal static let vaultRecoveryErrorGalleryAccess = T.tr("Localizable", "vault_recovery_error_gallery_access", fallback: "There was an error while accessing the file from Gallery. Ensure you have an internet connection and try again.")
  /// Can't open the file
  internal static let vaultRecoveryErrorOpenFile = T.tr("Localizable", "vault_recovery_error_open_file", fallback: "Can't open the file")
  /// Ensure you have access to the file.
  internal static let vaultRecoveryErrorOpenFileAccessExplain = T.tr("Localizable", "vault_recovery_error_open_file_access_explain", fallback: "Ensure you have access to the file.")
  /// Can't open the file. %@
  internal static func vaultRecoveryErrorOpenFileDetails(_ p1: Any) -> String {
    return T.tr("Localizable", "vault_recovery_error_open_file_details", String(describing: p1), fallback: "Can't open the file. %@")
  }
  /// Error scanning file. Check if the QR code is visible and that there's only one in the image.
  internal static let vaultRecoveryErrorScanningFile = T.tr("Localizable", "vault_recovery_error_scanning_file", fallback: "Error scanning file. Check if the QR code is visible and that there's only one in the image.")
  /// Wrong Master Password or Words. Try again.
  internal static let vaultRecoveryErrorWrongMasterPasswordWords = T.tr("Localizable", "vault_recovery_error_wrong_master_password_words", fallback: "Wrong Master Password or Words. Try again.")
  /// Allow Untrusted Certificates
  internal static let webdavAllowUntrustedCertificates = T.tr("Localizable", "webdav_allow_untrusted_certificates", fallback: "Allow Untrusted Certificates")
  /// Connect
  internal static let webdavConnect = T.tr("Localizable", "webdav_connect", fallback: "Connect")
  /// Connecting
  internal static let webdavConnecting = T.tr("Localizable", "webdav_connecting", fallback: "Connecting")
  /// Credentials
  internal static let webdavCredentials = T.tr("Localizable", "webdav_credentials", fallback: "Credentials")
  /// Disable iCloud sync
  internal static let webdavDisableIcloudConfirmBody = T.tr("Localizable", "webdav_disable_icloud_confirm_body", fallback: "Disable iCloud sync")
  /// Are you sure?
  internal static let webdavDisableIcloudConfirmTitle = T.tr("Localizable", "webdav_disable_icloud_confirm_title", fallback: "Are you sure?")
  /// Disable WebDAV
  internal static let webdavDisableWebdavConfirmBody = T.tr("Localizable", "webdav_disable_webdav_confirm_body", fallback: "Disable WebDAV")
  /// Disconnect
  internal static let webdavDisconnect = T.tr("Localizable", "webdav_disconnect", fallback: "Disconnect")
  /// Password
  internal static let webdavPassword = T.tr("Localizable", "webdav_password", fallback: "Password")
  /// Server URL
  internal static let webdavServerUrl = T.tr("Localizable", "webdav_server_url", fallback: "Server URL")
  /// Username
  internal static let webdavUsername = T.tr("Localizable", "webdav_username", fallback: "Username")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension T {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
