import Foundation
import FocusLockCore

/// Tells Slack and Discord what LockIn is doing. Everything here is
/// best-effort: a network hiccup or a revoked token shows up as a message on
/// the Integrations page and never gets in the way of the timer.
@MainActor
final class IntegrationCoordinator: ObservableObject {
    @Published private(set) var slackMessage: String?
    @Published private(set) var discordMessage: String?
    @Published private(set) var discordStatus: DiscordPresence.Status = .off

    private let keychain = KeychainStore()
    private lazy var slack = SlackClient { [keychain] in keychain.string(for: .slackToken) }
    private let presence = DiscordPresence()

    /// Only undo what LockIn itself did: a status you set by hand is not ours
    /// to clear.
    private var slackStatusIsOurs = false
    private var slackSnoozeIsOurs = false
    private var lastPresence: DiscordPresence.Activity?
    private var lastPhase: SessionPhase?

    init() {
        presence.onStatus = { [weak self] status in
            self?.discordStatus = status
        }
    }

    var hasSlackToken: Bool { keychain.has(.slackToken) }
    var hasDiscordWebhook: Bool { keychain.has(.discordWebhook) }

    func saveSlackToken(_ token: String) {
        keychain.set(token, for: .slackToken)
        objectWillChange.send()
    }

    func saveDiscordWebhook(_ link: String) -> Bool {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || DiscordWebhook.isValidLink(trimmed) else {
            discordMessage = DiscordWebhook.WebhookError.invalidLink.errorDescription
            return false
        }
        keychain.set(trimmed, for: .discordWebhook)
        discordMessage = trimmed.isEmpty ? "Webhook removed." : "Webhook saved."
        objectWillChange.send()
        return true
    }

    func testSlack() {
        slackMessage = "Checking…"
        Task {
            do {
                let team = try await slack.verify()
                slackMessage = "Connected to \(team)."
            } catch {
                slackMessage = error.localizedDescription
            }
        }
    }

    func testDiscordWebhook() {
        guard let link = keychain.string(for: .discordWebhook) else {
            discordMessage = "Paste a webhook link first."
            return
        }
        discordMessage = "Sending a test message…"
        Task {
            do {
                try await DiscordWebhook.post("LockIn is connected. Recaps will show up here when a run ends.", to: link)
                discordMessage = "Test message sent."
            } catch {
                discordMessage = error.localizedDescription
            }
        }
    }

    // MARK: Session events

    func sessionChanged(_ snapshot: TimerSnapshot, config: AppConfig) {
        let settings = config.integrations
        syncSlack(snapshot, settings: settings, phaseChanged: snapshot.phase != lastPhase)
        syncDiscordPresence(snapshot, settings: settings)
        lastPhase = snapshot.phase
    }

    func runFinished(_ recap: RunRecap, config: AppConfig) {
        guard config.integrations.discordRecapEnabled, let link = keychain.string(for: .discordWebhook) else { return }
        Task {
            do {
                try await DiscordWebhook.post(recap.text, to: link)
                discordMessage = "Recap posted \(Self.clockTime(Date()))."
            } catch {
                discordMessage = error.localizedDescription
            }
        }
    }

    /// Leaves nothing behind that claims you are still focusing.
    func appWillTerminate() {
        presence.update(nil, clientID: "")
        guard slackStatusIsOurs || slackSnoozeIsOurs else { return }
        let clearStatus = slackStatusIsOurs
        let resume = slackSnoozeIsOurs
        let slack = self.slack
        // Termination does not wait for async work; give Slack a moment.
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            if clearStatus { try? await slack.clearStatus() }
            if resume { try? await slack.resumeNotifications() }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 2)
    }

    private func syncSlack(_ snapshot: TimerSnapshot, settings: IntegrationSettings, phaseChanged: Bool) {
        guard settings.slackEnabled, hasSlackToken else {
            if slackStatusIsOurs || slackSnoozeIsOurs {
                clearSlack()
            }
            return
        }
        guard phaseChanged else { return }

        switch snapshot.phase {
        case .focus:
            let endsAt = snapshot.phaseEndsAt
            let minutes = max(1, Int((snapshot.remainingSeconds / 60).rounded(.up)))
            let text = endsAt.map { "\(settings.slackStatusText) · back at \(Self.clockTime($0))" } ?? settings.slackStatusText
            slackStatusIsOurs = true
            slackSnoozeIsOurs = settings.slackPauseNotifications
            Task {
                do {
                    try await slack.setStatus(text: text, emoji: settings.slackStatusEmoji, until: endsAt)
                    if settings.slackPauseNotifications {
                        try await slack.pauseNotifications(minutes: minutes)
                    }
                    slackMessage = "Status set until \(endsAt.map(Self.clockTime) ?? "the block ends")."
                } catch {
                    slackMessage = error.localizedDescription
                }
            }
        default:
            clearSlack()
        }
    }

    private func clearSlack() {
        let clearStatus = slackStatusIsOurs
        let resume = slackSnoozeIsOurs
        slackStatusIsOurs = false
        slackSnoozeIsOurs = false
        guard clearStatus || resume else { return }
        Task {
            do {
                if clearStatus { try await slack.clearStatus() }
                if resume { try await slack.resumeNotifications() }
                slackMessage = "Status cleared."
            } catch {
                slackMessage = error.localizedDescription
            }
        }
    }

    private func syncDiscordPresence(_ snapshot: TimerSnapshot, settings: IntegrationSettings) {
        guard settings.discordPresenceEnabled, settings.hasValidDiscordClientID else {
            if lastPresence != nil {
                presence.update(nil, clientID: settings.discordClientID)
                lastPresence = nil
            }
            if !settings.discordPresenceEnabled {
                discordStatus = .off
            }
            return
        }

        let activity: DiscordPresence.Activity?
        switch snapshot.phase {
        case .focus:
            let goal = snapshot.task?.goal ?? ""
            activity = .init(
                details: snapshot.isStrict ? "Focusing · strict" : "Focusing",
                state: goal.isEmpty ? snapshot.task?.category : goal,
                endsAt: snapshot.phaseEndsAt
            )
        case .break:
            activity = .init(details: "On a break", state: "Block \(snapshot.currentCycle) done", endsAt: snapshot.phaseEndsAt)
        default:
            activity = nil
        }

        guard activity != lastPresence else { return }
        lastPresence = activity
        presence.update(activity, clientID: settings.discordClientID.trimmingCharacters(in: .whitespaces))
    }

    private static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
