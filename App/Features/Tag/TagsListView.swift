import CoreData
import SwiftUI

struct TagsListView: View {
    @Environment(Router.self) var router: Router
    @Environment(AppSync.self) var appSync: AppSync
    @State var viewModel = TagsListViewModel()

    var body: some View {
        List {
            ForEach(viewModel.tags) { tagWithCount in
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
            }
        }
        .refreshable {
            appSync.requestSync()
            viewModel.load()
        }
        .listStyle(.inset)
        .task {
            viewModel.load()
        }
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
    }
}
