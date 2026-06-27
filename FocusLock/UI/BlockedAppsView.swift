import AppKit
import FocusLockCore
import SwiftUI

struct BlockedAppsView: View {
    @EnvironmentObject private var controller: MenuBarController
    @State private var selection = Set<BlockedApp.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: FLSpacing.md) {
            HStack {
                FLSectionHeader(title: "Blocked apps")

                Spacer()

                Button {
                    controller.addBlockedAppFromPanel()
                } label: {
                    Label("Add App", systemImage: "plus")
                }
                .buttonStyle(FLActionButtonStyle(variant: .secondary))
            }

            if controller.config.blockedApps.isEmpty {
                FLEmptyState(
                    systemImage: "app.badge",
                    title: "No blocked apps",
                    detail: "Add distracting apps to protect your focus."
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List(selection: $selection) {
                    ForEach(controller.config.blockedApps) { app in
                        blockedAppRow(app)
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: 220)
                .onDeleteCommand(perform: removeSelectedApps)

                Text("Select an app and press Delete to remove it.")
                    .font(.caption2)
                    .foregroundStyle(Color.flTextTertiary)
            }
        }
    }

    private func removeSelectedApps() {
        let apps = controller.config.blockedApps.filter { selection.contains($0.id) }
        guard !apps.isEmpty else {
            return
        }

        for app in apps {
            controller.removeBlockedApp(app)
        }
        selection.removeAll()
    }

    private func blockedAppRow(_ app: BlockedApp) -> some View {
        HStack(spacing: FLSpacing.sm) {
            Image(systemName: "app")
                .foregroundStyle(Color.flTextTertiary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: FLRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.flTextPrimary)

                Text(app.bundleId)
                    .font(.caption)
                    .foregroundStyle(Color.flTextSecondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }

            Spacer()

            Button(role: .destructive) {
                controller.removeBlockedApp(app)
            } label: {
                Image(systemName: "minus.circle")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.flDestructive)
            .help("Remove \(app.name)")
            .accessibilityLabel("Remove \(app.name)")
        }
        .padding(.horizontal, FLSpacing.sm)
        .padding(.vertical, FLSpacing.sm)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: FLRadius.md, style: .continuous))
        .contextMenu {
            Button("Copy Bundle Identifier") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(app.bundleId, forType: .string)
            }
            Divider()
            Button("Remove \(app.name)", role: .destructive) {
                controller.removeBlockedApp(app)
            }
        }
    }
}
