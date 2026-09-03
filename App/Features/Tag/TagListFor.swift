import CoreData
import SwiftUI

struct TagListFor: View {
    @EnvironmentObject var appState: AppState
    @State private var tagLabel: String = ""
    @ObservedObject var entry: Entry

    @State var viewModel = TagsForEntryViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("New tag") {
                    HStack {
                        TextField("Tag name", text: $tagLabel)
                        Button(action: {
                            Task {
                                await viewModel.add(tag: tagLabel, for: entry)
                                tagLabel = ""
                            }
                        }, label: {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Add")
                            }
                        })
                        .disabled(viewModel.isLoading || tagLabel.isEmpty)
                    }
                }

                Section("Selected tags") {
                    if viewModel.selectedTags.isEmpty {
                        Text("No tags selected")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.selectedTags) { tag in
                            Button(action: {
                                Task {
                                    await viewModel.toggle(tag: tag, for: entry)
                                }
                            }, label: {
                                Text(tag.label)
                                    .contentShape(Rectangle())
                            })
                            .buttonStyle(.plain)
                            .disabled(viewModel.isLoading)
                        }
                    }
                }

                Section("Tags") {
                    if viewModel.availableTags.isEmpty {
                        Text("No more tags available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.availableTags) { tag in
                            Button(action: {
                                Task {
                                    await viewModel.toggle(tag: tag, for: entry)
                                }
                            }, label: {
                                Text(tag.label)
                                    .contentShape(Rectangle())
                            })
                            .buttonStyle(.plain)
                            .disabled(viewModel.isLoading)
                        }
                    }
                }
            }
            .task {
                await viewModel.load(for: entry)
            }
            .navigationTitle("Tag")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

/*
 struct TagListFor_Previews: PreviewProvider {
 static var previews: some View {
     TagListFor(entry: Entry())
 }
 }*/
