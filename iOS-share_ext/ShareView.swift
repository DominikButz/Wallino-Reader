import SharedLib
import SwiftUI
import WallabagKit

struct ShareView: View {
    @Bindable var viewModel: ShareViewModel

    private var pdfProgressLabel: String {
        if viewModel.pdfProgressTotal > 1 {
            return String(format: "Converting PDF… page %d of %d".localized, arguments: [viewModel.pdfProgressPage, viewModel.pdfProgressTotal])
        }
        return "Converting PDF…".localized
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isPDF {
                    pdfSection
                } else {
                    linkSection
                }

                if viewModel.isPDF {
                    Section {
                        TextField("Title", text: $viewModel.entryTitle)
                        TextField("Domain name, e.g. newspaper.com (optional)", text: $viewModel.domainName)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    Toggle("Mark as read", isOn: $viewModel.isRead)
                    Toggle("Mark as favorite", isOn: $viewModel.isStarred)
                }

                Section("New tag") {
                    HStack {
                        TextField("Tag name", text: $viewModel.newTagLabel)
                            .textInputAutocapitalization(.never)
                        Button("Add") {
                            viewModel.addNewTag()
                        }
                        .disabled(viewModel.newTagLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Selected tags") {
                    if viewModel.selectedTags.isEmpty {
                        Text("No tags selected")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.selectedTags, id: \.self) { label in
                            Button {
                                viewModel.selectedTags.removeAll { $0 == label }
                            } label: {
                                Label(label, systemImage: "checkmark")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Tags") {
                    if viewModel.selectableTags.isEmpty {
                        Text("No more tags available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.selectableTags, id: \.id) { tag in
                            Button {
                                viewModel.toggle(tag)
                            } label: {
                                Text(tag.label)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add entry")
            .searchable(text: $viewModel.search, prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancel()
                    }
                    .disabled(viewModel.isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task {
                                await viewModel.save()
                            }
                        }
                        .disabled(!viewModel.canAdd)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("Ok", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog(
                "The PDF is too long",
                isPresented: $viewModel.showTruncationConfirmation,
                titleVisibility: .visible
            ) {
                Button("Import partial text") {
                    viewModel.confirmTruncatedImport()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelTruncatedImport()
                }
            } message: {
                if let pending = viewModel.pendingTruncation {
                    Text(
                        String(
                            format: "Only the first %d of %d characters of the PDF text will be imported".localized,
                            arguments: [pending.importedCharacterCount, pending.totalCharacterCount]
                        )
                    )
                }
            }
        }
    }

    private var linkSection: some View {
        Section {
            if let title = viewModel.pageTitle, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            ForEach(viewModel.urls, id: \.self) { url in
                Text(url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pdfSection: some View {
        Section {
            if let fileName = viewModel.pdfFileName {
                HStack(spacing: 12) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileName)
                            .lineLimit(2)

                        if viewModel.pdfPageCount > 0 {
                            Text(String(format: "%d pages".localized, arguments: [viewModel.pdfPageCount]))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if viewModel.isConvertingPDF {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(pdfProgressLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let pdfError = viewModel.pdfError {
                Text(pdfError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }
}
