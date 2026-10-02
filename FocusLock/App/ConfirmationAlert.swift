import AppKit

/// "Are you sure?" for the things that cannot be taken back. The safe choice
/// is the default button, so a stray Return keeps what was running.
@MainActor
enum ConfirmationAlert {
    struct Answer {
        var confirmed: Bool
        /// The user ticked "Don't ask again".
        var suppress: Bool
    }

    static func ask(
        title: String,
        message: String,
        confirm: String,
        keep: String,
        suppressible: Bool = false
    ) -> Answer {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message

        let keepButton = alert.addButton(withTitle: keep)
        keepButton.keyEquivalent = "\r"
        let confirmButton = alert.addButton(withTitle: confirm)
        confirmButton.hasDestructiveAction = true
        confirmButton.keyEquivalent = ""

        alert.showsSuppressionButton = suppressible
        alert.suppressionButton?.title = "Don’t ask again"

        // A request can come from a hotkey or the menu bar while another app
        // is in front. (A guard screen is dismissed by its caller first: a
        // modal alert cannot be raised above it.)
        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()
        return Answer(
            confirmed: response == .alertSecondButtonReturn,
            suppress: alert.suppressionButton?.state == .on
        )
    }
}
