import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@available(iOS 26.0, macOS 26.0, *)
struct SummarySheet: View {
    let viewModel: SummaryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Summarizing…")
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ScrollView {
                        Text(viewModel.summary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .navigationTitle("Summary")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            copyToClipboard()
                        } label: {
                            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        }
                        .disabled(!viewModel.hasSummary)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private func copyToClipboard() {
        #if os(iOS)
            UIPasteboard.general.string = viewModel.summary
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(viewModel.summary, forType: .string)
        #endif
        didCopy = true
    }
}
