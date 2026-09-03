import CoreData
import SwiftUI

struct EntriesForTagView: View {
    @AppStorage("entriesSortedById") var entriesSortedById = true
    @AppStorage("entriesSortedByReadingTime") var entriesSortedByReadingTime = false
    @AppStorage("entriesSortedByAscending") var entriesSortedByAscending = false

    let tag: Tag

    var body: some View {
        EntriesListView(
            predicate: NSPredicate(format: "ANY tags == %@", tag),
            entriesSortedById: entriesSortedById,
            entriesSortedByReadingTime: entriesSortedByReadingTime,
            entriesSortedByAscending: entriesSortedByAscending
        )
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu(content: {
                    Toggle("Order by id", systemImage: "line.3.horizontal.decrease.circle", isOn: $entriesSortedById)
                    Toggle("Order by reading time", systemImage: "clock.arrow.circlepath", isOn: $entriesSortedByReadingTime)
                    Divider()
                    Toggle("Sorting", systemImage: entriesSortedByAscending ? "arrow.up.circle" : "arrow.down.circle", isOn: $entriesSortedByAscending)
                }, label: {
                    Label("Sort options", systemImage: "line.3.horizontal.decrease.circle")
                })
            }
        }
        .navigationTitle(tag.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
