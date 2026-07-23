import SwiftUI

struct ExportView: View {
    @EnvironmentObject private var controller: MenuBarController

    var body: some View {
        HStack(spacing: FLSpacing.md) {
            Button("Export CSV") {
                controller.exportCSVFromPanel()
            }
            .buttonStyle(FLLinkButtonStyle())
            .accessibilityLabel("Export history as CSV")

            Button("Export JSON") {
                controller.exportJSONFromPanel()
            }
            .buttonStyle(FLLinkButtonStyle())
            .accessibilityLabel("Export history as JSON")
        }
        .disabled(controller.history.isEmpty)
        .opacity(controller.history.isEmpty ? 0.45 : 1)
        .accessibilityElement(children: .contain)
    }
}
