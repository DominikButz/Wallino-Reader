import SwiftUI
import WallabagKit

struct ShareView: View {
    @Bindable var viewModel: ShareViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let title = viewModel.title, !title.isEmpty {
                        Text(title)
                            .font(.headline)
                    }
                    ForEach(viewModel.urls, id: \.self) { url in
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        }
    }
}
