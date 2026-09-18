import AppIntents
import CoreData
import Foundation
import SwiftUI

struct EntriesListView: View {
    @Environment(\.managedObjectContext) var context: NSManagedObjectContext
    @Environment(AppSync.self) var appSync: AppSync
    @FetchRequest var entries: FetchedResults<Entry>
    @State private var autoTagMessage: String?

    init(
        predicate: NSPredicate,
        entriesSortedByCreatedDate: Bool,
        entriesSortedByReadingTime: Bool,
        entriesSortedByAscending: Bool
    ) {
        var sortDescriptors: [NSSortDescriptor] = []
        if entriesSortedByCreatedDate {
            sortDescriptors.append(NSSortDescriptor(key: "createdAt", ascending: entriesSortedByAscending))
        }

        if entriesSortedByReadingTime {
            sortDescriptors.append(NSSortDescriptor(key: "readingTime", ascending: entriesSortedByAscending))
        }

        let fetchRequest = NSFetchRequest<Entry>(entityName: "Entry")
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate
        fetchRequest.relationshipKeyPathsForPrefetching = ["tags"]

        _entries = FetchRequest(fetchRequest: fetchRequest, animation: nil)
    }

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: RoutePath.entry(entry)) {
                    EntryRowView(entry: entry)
                        .contentShape(Rectangle())
                        .entryEntityAnnotation(entry)
                        .contextMenu {
                            ArchiveEntryButton(entry: entry)
                            StarEntryButton(entry: entry)
                            if #available(iOS 26.0, macOS 26.0, *), AutoTagService.isAvailable {
                                Divider()
                                AutoTagButton(entry: entry) { message in
                                    autoTagMessage = message
                                }
                            }
                        }
                }
                .buttonStyle(.plain)
                .swipeActions(allowsFullSwipe: false, content: {
                    ArchiveEntryButton(entry: entry)
                        .tint(.blue)
                        .labelStyle(.iconOnly)
                    StarEntryButton(entry: entry)
                        .tint(.orange)
                        .labelStyle(.iconOnly)
                    Button(action: {
                        context.delete(entry)
                    }, label: {
                        Label("Delete", systemImage: "trash")
                    })
                    .tint(.red)
                    .labelStyle(.iconOnly)
                })
            }
        }
        .refreshable { appSync.requestSync() }
        .listStyle(.inset)
        .alert("Auto-tag", isPresented: Binding(
            get: { autoTagMessage != nil },
            set: { if !$0 { autoTagMessage = nil } }
        )) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text(autoTagMessage ?? "")
        }
    }
}

extension View {
    @ViewBuilder
    func entryEntityAnnotation(_ entry: Entry) -> some View {
        if #available(iOS 18.4, macOS 15.4, *) {
            appEntityIdentifier(EntityIdentifier(for: EntryEntity.self, identifier: entry.id))
        } else {
            self
        }
    }
}
