import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct EntryAIActionsMenu: View {
    @ObservedObject var entry: Entry

    @State private var autoTagViewModel = AutoTagViewModel()
    @State private var summaryViewModel = SummaryViewModel()
    @State private var showSummary = false
    @State private var autoTagMessage: String?

    var body: some View {
        Menu {
            Button {
                Task {
                    let outcome = await autoTagViewModel.autoTag(entry: entry)
                    autoTagMessage = AutoTagViewModel.localizedMessage(for: outcome)
                }
            } label: {
                Label("Auto-tag", systemImage: "wand.and.stars")
            }
            .disabled(autoTagViewModel.isGenerating)

            Button {
                showSummary = true
                Task {
                    await summaryViewModel.summarize(entry: entry)
                }
            } label: {
                Label("Summarize", systemImage: "text.line3.summary")
            }
        } label: {
            Label("AI actions", systemImage: "apple.intelligence")
                .labelStyle(.iconOnly)
        }
        .accessibilityLabel("AI actions")
        .alert("Auto-tag", isPresented: Binding(
            get: { autoTagMessage != nil },
            set: { if !$0 { autoTagMessage = nil } }
        )) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text(autoTagMessage ?? "")
        }
        .sheet(isPresented: $showSummary) {
            SummarySheet(viewModel: summaryViewModel)
        }
    }
}
