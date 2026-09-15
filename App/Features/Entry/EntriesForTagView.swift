import CoreData
import SwiftUI

struct EntriesForTagView: View {
    @AppStorage("entriesSortedByCreatedDate") var entriesSortedByCreatedDate = true
    @AppStorage("entriesSortedByReadingTime") var entriesSortedByReadingTime = false
    @AppStorage("entriesSortedByAscending") var entriesSortedByAscending = false

    let tag: Tag

    var body: some View {
        EntriesListView(
            predicate: NSPredicate(format: "ANY tags == %@", tag),
            entriesSortedByCreatedDate: entriesSortedByCreatedDate,
            entriesSortedByReadingTime: entriesSortedByReadingTime,
            entriesSortedByAscending: entriesSortedByAscending
        )
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu(content: {
                    Toggle("Order by date", systemImage: "line.3.horizontal.decrease.circle", isOn: $entriesSortedByCreatedDate)
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
