import FocusLockCore
import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        IntegrationsContent(integrations: controller.integrations)
    }
}

private struct IntegrationsContent: View {
    @EnvironmentObject private var controller: MenuBarController
    @ObservedObject var integrations: IntegrationCoordinator

    @State private var slackToken = ""
    @State private var webhook = ""

    private var settings: IntegrationSettings { controller.config.integrations }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Integrations")
                    .font(FLTypography.display)
                    .foregroundStyle(Color.flInk)
                Text("Let Slack and Discord know you're heads-down. Tokens are kept in your Keychain.")
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FLRule()
                    slackSection
                    FLRule()
                    discordPresenceSection
                    FLRule()
                    discordRecapSection
                    FLRule()
                    shortcutsSection
                }
            }
        }
    }

    // MARK: Slack

    private var slackSection: some View {
        section("Slack") {
            toggle("Set my Slack status during focus",
                   detail: "“\(settings.slackStatusText) · back at 10:45” with an emoji, cleared when the block ends.",
                   isOn: setting(\.slackEnabled))

            toggle("Pause Slack notifications during focus",
                   detail: "Snoozes notifications for exactly the length of the block.",
                   isOn: setting(\.slackPauseNotifications))
                .disabled(!settings.slackEnabled)

            HStack(spacing: 10) {
                TextField("Status text", text: setting(\.slackStatusText))
                    .flField(width: 180)
                TextField(":emoji:", text: setting(\.slackStatusEmoji))
                    .flField(width: 110)
            }
            .disabled(!settings.slackEnabled)

            HStack(spacing: 10) {
                SecureField(integrations.hasSlackToken ? "Token saved — paste to replace" : "User token (xoxp-…)", text: $slackToken)
                    .flField(width: 300)
                Button("Save") {
                    integrations.saveSlackToken(slackToken)
                    slackToken = ""
                    integrations.testSlack()
                }
                .buttonStyle(FLInlineButtonStyle())
                .disabled(slackToken.isEmpty)
                Button("Test") { integrations.testSlack() }
                    .buttonStyle(FLInlineButtonStyle())
                    .disabled(!integrations.hasSlackToken)
                if integrations.hasSlackToken {
                    Button("Remove") { integrations.saveSlackToken("") }
                        .buttonStyle(FLLinkButtonStyle(tint: .flClay))
                }
            }

            status(integrations.slackMessage)

            DisclosureGroup("How to get a token") {
                Text("""
                1. Go to api.slack.com/apps › Create New App › From scratch, and pick your workspace.
                2. OAuth & Permissions › User Token Scopes: add users.profile:write and dnd:write.
                3. Install to Workspace, then copy the User OAuth Token (starts with xoxp-) and paste it here.
                """)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            }
            .font(FLTypography.caption)
        }
    }

    // MARK: Discord

    private var discordPresenceSection: some View {
        section("Discord status") {
            toggle("Show what I'm doing on my Discord profile",
                   detail: "Rich Presence: “Focusing · 18 min left” under your name. The Discord desktop app has to be running.",
                   isOn: setting(\.discordPresenceEnabled))

            HStack(spacing: 10) {
                TextField("Application ID", text: setting(\.discordClientID))
                    .flField(width: 240)
                presenceBadge
            }
            .disabled(!settings.discordPresenceEnabled)

            if settings.discordPresenceEnabled && !settings.hasValidDiscordClientID {
                status("That doesn't look like an Application ID — it's a long number.")
            }

            DisclosureGroup("How to get an Application ID") {
                Text("""
                1. Go to discord.com/developers/applications › New Application, and name it “LockIn” — that name is what your profile shows.
                2. Copy the Application ID from General Information and paste it here.
                3. Optional: Rich Presence › Art Assets, upload an image named “lockin” to show it beside the status.
                LockIn can't change your custom status text: Discord only allows that with your account token, which breaks its rules.
                """)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            }
            .font(FLTypography.caption)
        }
    }

    @ViewBuilder
    private var presenceBadge: some View {
        switch integrations.discordStatus {
        case .connected:
            FLBadge(text: "Connected")
        case .discordNotRunning:
            FLBadge(text: "Discord not running", tint: .flInkSoft, borderTint: .flHairline)
        case .failed(let reason):
            Text(reason)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flClay)
                .lineLimit(2)
        case .off:
            EmptyView()
        }
    }

    private var discordRecapSection: some View {
        section("Discord recap") {
            toggle("Post a recap to a channel when a run ends",
                   detail: "Blocks, focus time, categories, and goals — the same text as Copy recap.",
                   isOn: setting(\.discordRecapEnabled))

            HStack(spacing: 10) {
                SecureField(integrations.hasDiscordWebhook ? "Webhook saved — paste to replace" : "Webhook link", text: $webhook)
                    .flField(width: 360)
                Button("Save") {
                    if integrations.saveDiscordWebhook(webhook) {
                        webhook = ""
                    }
                }
                .buttonStyle(FLInlineButtonStyle())
                .disabled(webhook.isEmpty)
                Button("Send test") { integrations.testDiscordWebhook() }
                    .buttonStyle(FLInlineButtonStyle())
                    .disabled(!integrations.hasDiscordWebhook)
                if integrations.hasDiscordWebhook {
                    Button("Remove") { _ = integrations.saveDiscordWebhook("") }
                        .buttonStyle(FLLinkButtonStyle(tint: .flClay))
                }
            }

            status(integrations.discordMessage)

            Text("In Discord: Server Settings › Integrations › Webhooks › New Webhook › Copy Webhook URL.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
        }
    }

    // MARK: Shortcuts & Focus

    private var shortcutsSection: some View {
        section("Shortcuts and Focus modes") {
            Text("LockIn adds Start Focus, Stop Focus, Skip to Next Phase, and Get Focus Status to the Shortcuts app and Spotlight.")
                .font(FLTypography.body)
                .foregroundStyle(Color.flInk)
                .fixedSize(horizontal: false, vertical: true)
            Text("To start a block with a macOS Focus: System Settings › Focus › pick a Focus › Focus Filters › Add Filter › LockIn, and turn on “Start a focus block”.")
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Button("Open Shortcuts") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
                .buttonStyle(FLLinkButtonStyle())
                Button("Open Focus settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(FLLinkButtonStyle())
            }
        }
    }

    // MARK: Building blocks

    private func setting<Value>(_ keyPath: WritableKeyPath<IntegrationSettings, Value>) -> Binding<Value> {
        Binding(
            get: { controller.config.integrations[keyPath: keyPath] },
            set: { value in controller.updateIntegrations { $0[keyPath: keyPath] = value } }
        )
    }

    @ViewBuilder
    private func status(_ message: String?) -> some View {
        if let message {
            Text(message)
                .font(FLTypography.caption)
                .foregroundStyle(Color.flInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FLMicroLabel(text: title)
            content()
        }
        .frame(maxWidth: 620, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: FLSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FLTypography.body)
                    .foregroundStyle(Color.flInk)
                Text(detail)
                    .font(FLTypography.caption)
                    .foregroundStyle(Color.flInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: FLSpacing.md)
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(Color.flAccentDeep)
                .labelsHidden()
                .accessibilityLabel(title)
        }
    }
}
