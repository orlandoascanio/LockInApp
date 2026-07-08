import SwiftUI

struct ExportView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .trailing, spacing: FLSpacing.xs) {
            HStack(spacing: FLSpacing.sm) {
                exportButton(
                    title: "CSV",
                    accessibilityTitle: "Export CSV",
                    systemImage: "tablecells"
                ) {
                    controller.exportCSVFromPanel()
                }

                exportButton(
                    title: "JSON",
                    accessibilityTitle: "Export JSON",
                    systemImage: "curlybraces"
                ) {
                    controller.exportJSONFromPanel()
                }
            }

            if let message = controller.exportMessage {
                HStack(spacing: FLSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.flSuccess)
                        .symbolRenderingMode(.hierarchical)

                    Text(message)
                        .foregroundStyle(Color.flTextSecondary)
                        .lineLimit(1)

                }
                .font(.caption2)
                .transition(.opacity)
                .help(message)
            }
        }
        .frame(maxWidth: 240, alignment: .trailing)
        .accessibilityElement(children: .contain)
    }

    private func exportButton(
        title: String,
        accessibilityTitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help(accessibilityTitle)
        .accessibilityLabel(accessibilityTitle)
    }
}
