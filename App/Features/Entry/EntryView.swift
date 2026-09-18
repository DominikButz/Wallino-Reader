import CoreData
import Factory
import HTMLEntities
import SwiftUI

struct EntryView: View {
    @Environment(\.managedObjectContext) var context: NSManagedObjectContext
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSync.self) var appSync: AppSync
    #if os(iOS)
        @Environment(PlayerPublisher.self) var player: PlayerPublisher
    #endif
    @ObservedObject var entry: Entry
    @State var showTag: Bool = false
    @State private var showDeleteConfirm = false
    @State private var progress = 0.0
    #if os(iOS)
        @StateObject private var annotationEditor = AnnotationEditorViewModel()
        @State private var pdfShareFile: ShareableFile?
        @State private var isGeneratingPDF = false
    #endif

    #if os(iOS)
        let toolbarPlacement: ToolbarItemPlacement = .bottomBar
    #else
        let toolbarPlacement: ToolbarItemPlacement = .primaryAction
    #endif

    var body: some View {
        Group {
            #if os(iOS)
                WebView(entry: entry, progress: $progress, annotationEditor: annotationEditor)
            #else
                WebView(entry: entry, progress: $progress)
            #endif
        }
        .ignoresSafeArea()
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    ProgressView(value: max(0, min(progress, 1)), total: 1)
                    if !entry.tags.isEmpty && progress <= 0 {
                        tagsView
                    }
                }
            }
            .addSwipeToBack {
                dismiss()
            }
        .toolbar {
            ToolbarItem(placement: toolbarPlacement) {
                Menu(content: {
                    bottomBarButton
                }, label: {
                    Label("Entry option", systemImage: "filemenu.and.selection")
                        .foregroundColor(.primary)
                        .labelStyle(.iconOnly)
                })
                .accessibilityLabel("Entry option")
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
            }
            ToolbarItem(placement: toolbarPlacement) {
                FontSizeSelectorView()
            }
            if #available(iOS 26.0, macOS 26.0, *), AutoTagService.isAvailable {
                ToolbarItem(placement: toolbarPlacement) {
                    EntryAIActionsMenu(entry: entry)
                }
            }
        }
        .alert("Confirm delete?", isPresented: $showDeleteConfirm) {
            Button(role: .destructive, action: {
                context.delete(entry)
                dismiss()
            }, label: {
                Text("Delete")
            })
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showTag) {
            TagListFor(entry: entry)
                .presentationDetents([.medium, .large])
        }
        #if os(iOS)
            .sheet(item: $annotationEditor.state) { _ in
                AnnotationEditorView(viewModel: annotationEditor)
                    .presentationDetents([.medium, .large])
            }
        #endif
        #if os(iOS)
            .sheet(item: $pdfShareFile) { file in
                ActivityView(activityItems: [file.url])
            }
        #endif
        .toolbarBackground(.ultraThinMaterial, for: .bottomBar)
        .toolbarBackground(.visible, for: .bottomBar)
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(.all, edges: .bottom)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var tagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(entry.tags.sorted(by: >)) { tag in
                    HStack(spacing: 2) {
                        Image(systemName: "tag")
                        Text(tag.label)
                    }
                    .foregroundStyle(Color.primary)
                    .padding(4)
                    .background(
                        Capsule()
                            .fill(Color.gray.quaternary)
                            .clipped()
                    )
                    .clipShape(Capsule())
                    .font(.footnote)
                }
            }
            .padding(.horizontal)
        }
        .padding(.leading, 5)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var bottomBarButton: some View {
        Button(role: .destructive, action: {
            showDeleteConfirm = true
        }, label: {
            Label("Delete", systemImage: "trash")
        })
        Divider()
        Button(action: {
            openURL(entry.url!.url!)
        }, label: {
            Label("Open in Safari", systemImage: "safari")
        })
        if let url = entry.url?.url {
            ShareLink(item: url) {
                Label("Share URL", systemImage: "square.and.arrow.up")
            }
        }
        #if os(iOS)
            Button(action: shareAsPDF, label: {
                Label("Share as PDF", systemImage: "doc.richtext")
            })
            .disabled(isGeneratingPDF)
        #endif
        Button(action: {
            showTag.toggle()
        }, label: {
            Label("Tags", systemImage: showTag ? "tag.fill" : "tag")
        })
        Button(action: {
            appSync.refresh(entry: entry)
        }, label: {
            Label("Refresh", systemImage: "arrow.counterclockwise")
        })
        StarEntryButton(entry: entry, showText: true)
        #if os(iOS)
            .hapticNotification(.success)
        #endif
        ArchiveEntryButton(entry: entry, showText: true) {
            dismiss()
        }
        #if os(iOS)
        .hapticNotification(.success)
        #endif
        #if os(iOS)
            Button(action: {
                player.load(entry)
            }, label: {
                Label("Text-to-speech", systemImage: "music.note")
            })
            .accessibilityHint("Load entry in text-to-speech player")
        #endif
    }

    #if os(iOS)
        private func shareAsPDF() {
            guard !isGeneratingPDF else { return }
            isGeneratingPDF = true

            let articleHTML = entry.titleHtml + (entry.content ?? "")
            Task { @MainActor in
                defer { isGeneratingPDF = false }
                do {
                    let data = try await EntryPDFGenerator().generatePDF(articleHTML: articleHTML)
                    let sanitizedTitle = (entry.title ?? "")
                        .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
                        .joined()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let filename = "\(sanitizedTitle.isEmpty ? "article" : sanitizedTitle).pdf"
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                    try data.write(to: url)
                    pdfShareFile = ShareableFile(url: url)
                } catch {}
            }
        }
    #endif
}

#if DEBUG
    struct EntryView_Previews: PreviewProvider {
        static var previews: some View {
            let coreData = Container.shared.coreData()
            EntryView(entry: Entry(context: coreData.viewContext))
                .environment(AppSync())
                .environmentObject(AppSetting())
            #if os(iOS)
                .environment(PlayerPublisher())
            #endif
                .environment(\.managedObjectContext, coreData.viewContext)
        }
    }
#endif
