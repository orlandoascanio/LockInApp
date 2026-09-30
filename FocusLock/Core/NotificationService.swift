import Foundation
import UserNotifications

public protocol NotificationSending: AnyObject {
    func requestAuthorization()
    func focusStarted(minutes: Int)
    func focusCompleted()
    func breakStarted(minutes: Int, cycle: Int)
    func breakEnded()
    func sessionCancelled()
    func blockedAppHidden(name: String)
}

public final class NotificationService: NSObject, NotificationSending, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter?

    /// What to suggest doing with a break, by block number and length. Set by
    /// the app, which owns the settings; `nil` sends the plain notice.
    public var breakSuggestion: ((_ cycle: Int, _ minutes: Int) -> BreakSuggestion?)?

    public init(center: UNUserNotificationCenter? = nil) {
        self.center = center ?? Self.resolveCenter()
        super.init()
        self.center?.delegate = self
    }

    /// `UNUserNotificationCenter.current()` raises an uncatchable Objective-C
    /// exception ("bundleProxyForCurrentProcess is nil") when the process is not
    /// running from a real app bundle (for example, a bare command-line launch of
    /// the executable). That exception aborts the whole app before it can finish
    /// launching. Resolve the center only when a bundle context exists, and treat
    /// notifications as a no-op otherwise so the app never crashes on launch.
    private static func resolveCenter() -> UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else {
            FocusLockLog.debug("notifications disabled: no app bundle context")
            return nil
        }
        return UNUserNotificationCenter.current()
    }

    public func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func focusStarted(minutes: Int) {
        send(title: "Focus started", body: "\(minutes) minutes locked in.")
    }

    public func focusCompleted() {
        send(title: "Focus completed", body: "Nice work. Time for a break.")
    }

    public func breakStarted(minutes: Int, cycle: Int) {
        if let suggestion = breakSuggestion?(cycle, minutes) {
            send(title: "Break · \(minutes) min — \(suggestion.title)", body: suggestion.detail)
        } else {
            send(title: "Break started", body: "\(minutes) minutes to reset.")
        }
    }

    public func eyeReminder() {
        send(title: BreakSuggestions.eyeReminder.title, body: BreakSuggestions.eyeReminder.detail, sound: false)
    }

    public func scheduleStarted(name: String, strict: Bool) {
        send(title: "\(name) schedule started", body: strict ? "Strict mode is on for this block." : "Focus is running.")
    }

    public func notice(title: String, body: String) {
        send(title: title, body: body)
    }

    public func breakEnded() {
        send(title: "Break is done.", body: "Time to get locked in again.")
    }

    public func sessionCancelled() {
        send(title: "Session cancelled", body: "Blocking has stopped.")
    }

    public func blockedAppHidden(name: String) {
        send(title: "\(name) is guarded during focus mode.", body: "It keeps running in the background.")
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func send(title: String, body: String, sound: Bool = true) {
        guard let center else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound ? .default : nil

        let request = UNNotificationRequest(
            identifier: "lockin-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}

public final class NoopNotificationService: NotificationSending {
    public private(set) var events: [String] = []

    public init() {}

    public func requestAuthorization() {
        events.append("requestAuthorization")
    }

    public func focusStarted(minutes: Int) {
        events.append("focusStarted:\(minutes)")
    }

    public func focusCompleted() {
        events.append("focusCompleted")
    }

    public func breakStarted(minutes: Int, cycle: Int) {
        events.append("breakStarted:\(minutes)")
    }

    public func breakEnded() {
        events.append("breakEnded")
    }

    public func sessionCancelled() {
        events.append("sessionCancelled")
    }

    public func blockedAppHidden(name: String) {
        events.append("blockedAppHidden:\(name)")
    }
}
