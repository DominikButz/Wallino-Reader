import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct AutoTagButton: View {
    @ObservedObject var entry: Entry
    let onMessage: (String) -> Void

    @State private var viewModel = AutoTagViewModel()

    var body: some View {
        Button {
            Task {
                let outcome = await viewModel.autoTag(entry: entry)
                onMessage(AutoTagViewModel.localizedMessage(for: outcome))
            }
        } label: {
            Label("Auto-tag", systemImage: "wand.and.stars")
        }
        .disabled(viewModel.isGenerating)
    }
}
