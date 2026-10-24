import CoreData
import SwiftUI

struct TagsListView: View {
    @Environment(Router.self) var router: Router
    @Environment(AppSync.self) var appSync: AppSync
    @Environment(\.palette) private var palette
    @State var viewModel = TagsListViewModel()

    var body: some View {
        List {
            ForEach(viewModel.filteredTags) { tagWithCount in
                Button(action: {
                    router.tagsPath.append(RoutePath.entriesForTag(tagWithCount.tag))
                }, label: {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                        Text(tagWithCount.label)
                        Spacer()
                        Text("\(tagWithCount.entryCount)")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .contentShape(Rectangle())
                })
                .buttonStyle(.plain)
                .listRowBackground(palette.surface)
            }
        }
        .searchable(text: $viewModel.search, prompt: "Search")
        .refreshable {
            appSync.requestSync()
            viewModel.load()
        }
        .accessibilityIdentifier("tags_list")
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .task {
            viewModel.load()
        }
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
    }
}
