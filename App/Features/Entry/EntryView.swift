import CoreData
import Factory
import HTMLEntities
import SharedLib
import SwiftUI

struct EntryView: View {
    @Environment(\.managedObjectContext) var context: NSManagedObjectContext
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
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
        ZStack {
            if entry.isContentUnavailable {
                unavailableView
            } else {
                readerView
            }
        }
        .accessibilityIdentifier("entry_detail")
        .background(palette.background)
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
                .accessibilityIdentifier("entry_option_menu")
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
    private var readerView: some View {
#if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // The Xcode canvas does not capture WKWebView content, so the
            // article would stay blank. Render it as native text instead.
            PreviewArticleView(entry: entry)
        } else {
            webReader
        }
#else
        webReader
#endif

    }

    @ViewBuilder
    private var webReader: some View {
        #if os(iOS)
            WebView(entry: entry, progress: $progress, annotationEditor: annotationEditor)
        #else
            WebView(entry: entry, progress: $progress)
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
                            .fill(palette.chipBackground)
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
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Article unavailable")
                .font(.headline)

            Text("The article content could not be retrieved. It may require a subscription or sign-in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let url = entry.url?.url {
                Button {
                    openURL(url)
                } label: {
                    Label("Open in Safari", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                appSync.refetch(entry: entry)
            } label: {
                Label("Refetch", systemImage: "arrow.counterclockwise")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button(action: {
                shareAsPDF()
            }, label: {
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
            appSync.refetch(entry: entry)
        }, label: {
            Label("Refetch", systemImage: "arrow.counterclockwise")
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
        /// In-memory store so sample objects never end up in the real library.
        static let previewContainer: NSPersistentContainer = {
            let container = NSPersistentContainer(name: "wallabagStore")
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
            container.loadPersistentStores { _, error in
                if let error {
                    assertionFailure("Could not load preview store: \(error)")
                }
            }
            return container
        }()

        /// Sample article so the preview canvas shows a real reader instead of
        /// the empty "Article unavailable" state.
        static let article: Entry = {
            let coreData = previewContainer
            let entry = Entry(context: coreData.viewContext)
            entry.id = 1
            entry.title = "Lorem ipsum dolor sit amet, consectetur adipiscing elit"
            entry.content = """
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer posuere erat a ante venenatis dapibus posuere velit aliquet. Cras mattis consectetur purus sit amet fermentum. Donec ullamcorper nulla non metus auctor fringilla.</p>
            <p>Maecenas faucibus mollis interdum. Vestibulum id ligula porta felis euismod semper. Aenean lacinia bibendum nulla sed consectetur. Nullam quis risus eget urna mollis ornare vel eu leo.</p>
            <h2>Sed posuere consectetur est at lobortis</h2>
            <p>Curabitur blandit tempus porttitor. Etiam porta sem malesuada magna mollis euismod. Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Vivamus sagittis lacus vel augue laoreet rutrum faucibus dolor auctor.</p>
            <blockquote><p>Donec sed odio dui. Praesent commodo cursus magna, vel scelerisque nisl consectetur et.</p></blockquote>
            <ul>
                <li>Fringilla euismod porttitor</li>
                <li>Nullam id dolor id nibh ultricies</li>
                <li>Cras justo odio dapibus ac facilisis</li>
            </ul>
            <p>Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia odio sem nec elit. Sed posuere consectetur est at lobortis.</p>
            """
            entry.url = "https://example.com/lorem-ipsum"
            entry.domainName = "example.com"
            entry.readingTime = 4
            entry.createdAt = Date()
            entry.updatedAt = Date()

            let firstTag = Tag(context: coreData.viewContext)
            firstTag.id = 1
            firstTag.label = "Swift"
            firstTag.slug = "swift"

            let secondTag = Tag(context: coreData.viewContext)
            secondTag.id = 2
            secondTag.label = "Reading"
            secondTag.slug = "reading"

            entry.tags = [firstTag, secondTag]

            return entry
        }()

        static var previews: some View {
            NavigationStack {
                EntryView(entry: article)
            }
            .environment(AppSync())
            .environmentObject(AppSetting())
            #if os(iOS)
                .environment(PlayerPublisher())
            #endif
            .environment(\.managedObjectContext, previewContainer.viewContext)
        }
    }

    /// Native stand-in for the reader in the Xcode canvas, which cannot render
    /// `WKWebView` content.
    private struct PreviewArticleView: View {
        let entry: Entry
        @Environment(\.palette) private var palette

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(entry.title?.htmlUnescape() ?? "")
                        .font(.largeTitle.bold())
                    Text(plainText(from: entry.content ?? ""))
                        .font(.body)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 56)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.background)
        }

        private func plainText(from html: String) -> String {
            html
                .replacingOccurrences(of: "</p>", with: "\n\n")
                .replacingOccurrences(of: "</h1>", with: "\n\n")
                .replacingOccurrences(of: "</h2>", with: "\n\n")
                .replacingOccurrences(of: "</h3>", with: "\n\n")
                .replacingOccurrences(of: "</li>", with: "\n")
                .replacingOccurrences(of: "</blockquote>", with: "\n\n")
                .replacingOccurrences(of: "<br>", with: "\n")
                .replacingOccurrences(of: "<br/>", with: "\n")
                .replacingOccurrences(of: "<br />", with: "\n")
                .withoutHTML
                .htmlUnescape()
                .replacingOccurrences(of: "\n\n\n", with: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
#endif
