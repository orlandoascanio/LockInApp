import Foundation

public enum AppIdentity {
    public static let name = "Quietwhile"
    /// Still the LockIn-era identifier, on purpose: Sparkle only installs an
    /// update whose bundle id matches, and macOS ties the Automation,
    /// notification and login-item permissions to it. The app group, URL type,
    /// launch agent label and UserDefaults keys keep "lockin" for the same reason.
    public static let bundleIdentifier = "com.lockin.app"
    /// Earlier names, newest first. Their Application Support folders are
    /// migrated from, and apps with these names count as this app.
    public static let legacyNames = ["LockIn", "FocusLock"]
    public static let legacyBundleIdentifier = "com.focuslock.app"
}
