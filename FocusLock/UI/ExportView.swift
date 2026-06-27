import SwiftUI

struct ExportView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: FLSpacing.md) {
            HStack(alignment: .top, spacing: FLSpacing.md) {
                VStack(alignment: .leading, spacing: FLSpacing.xs) {
                    FLSectionHeader(title: "Export", systemImage: "square.and.arrow.down")

                    Text("Export the session list.")
                        .font(.caption)
                        .foregroundStyle(Color.flTextSecondary)
                }

                Spacer()

                Button {
                    controller.exportCSVFromPanel()
                } label: {
                    Label("Export CSV", systemImage: "tablecells")
                }
                .buttonStyle(FLActionButtonStyle(variant: .secondary))

                Button {
                    controller.exportJSONFromPanel()
                } label: {
                    Label("Export JSON", systemImage: "curlybraces")
                }
                .buttonStyle(FLActionButtonStyle(variant: .secondary))
            }

            if let message = controller.exportMessage {
                HStack(spacing: FLSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.flSuccess)
                        .symbolRenderingMode(.hierarchical)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.flTextSecondary)

                    Spacer()
                }
                .padding(FLSpacing.sm)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: FLRadius.sm, style: .continuous))
            }
        }
    }
}
