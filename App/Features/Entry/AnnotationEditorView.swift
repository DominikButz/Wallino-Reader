import Factory
import SwiftUI
import WallabagKit
import WebKit

final class AnnotationEditorViewModel: ObservableObject {
    enum Mode {
        case add(quote: String, ranges: [AnnotationRange])
        case edit(id: Int, quote: String)
    }

    struct EditorState: Identifiable {
        let id = UUID()
        let mode: Mode
    }

    @Published var state: EditorState?
    @Published var text: String = ""

    weak var webView: WKWebView?
    @Injected(\.wallabagSession) private var session
    private var entryId: Int = 0

    var title: String {
        switch state?.mode {
        case .add:
            return NSLocalizedString("New annotation", bundle: .main, value: "New annotation", comment: "")
        case .edit:
            return NSLocalizedString("Edit annotation", bundle: .main, value: "Edit annotation", comment: "")
        case nil:
            return ""
        }
    }

    var selectedText: String {
        switch state?.mode {
        case .add(let quote, _):
            return quote
        case .edit(_, let quote):
            return quote
        case nil:
            return ""
        }
    }

    var isEditing: Bool {
        if case .edit = state?.mode {
            return true
        }
        return false
    }

    func presentAdd(quote: String, ranges: [AnnotationRange], entryId: Int) {
        self.entryId = entryId
        text = ""
        state = EditorState(mode: .add(quote: quote, ranges: ranges))
    }

    func presentEdit(id: Int, quote: String, text: String) {
        self.text = text
        state = EditorState(mode: .edit(id: id, quote: quote))
    }

    func cancel() {
        if case .add = state?.mode {
            webView?.evaluateJavaScript("window.__wallinoOnAnnotationAddCancelled()")
        }
        state = nil
    }

    func deleteAnnotation() {
        guard case .edit(let id, _) = state?.mode else { return }
        state = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                try await session.delete(annotation: id)
                removeHighlight(id: id)
            } catch {
                logger.error("Failed to delete annotation \(id): \(String(describing: error))")
            }
        }
    }

    func save() {
        guard let mode = state?.mode else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        state = nil

        switch mode {
        case .add(let quote, let ranges):
            let entryId = self.entryId
            Task { [weak self] in
                guard let self else { return }
                do {
                    if let id = try await session.add(annotation: trimmed, quote: quote, ranges: ranges, entryId: entryId) {
                        notifyAnnotationAdded(id: id, text: trimmed)
                    }
                } catch {
                    logger.error("Failed to add annotation: \(String(describing: error))")
                }
            }
        case .edit(let id, _):
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await session.update(annotation: id, text: trimmed)
                    notifyAnnotationUpdated(id: id, text: trimmed)
                } catch {
                    logger.error("Failed to update annotation \(id): \(String(describing: error))")
                }
            }
        }
    }

    private func notifyAnnotationAdded(id: Int, text: String) {
        guard let data = try? JSONEncoder().encode(text),
              let textJSON = String(data: data, encoding: .utf8)
        else {
            return
        }

        let script = "window.__wallinoOnAnnotationAdded(\(id), \(textJSON))"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script)
        }
    }

    private func notifyAnnotationUpdated(id: Int, text: String) {
        guard let data = try? JSONEncoder().encode(text),
              let textJSON = String(data: data, encoding: .utf8)
        else {
            return
        }

        let script = "window.__wallinoOnAnnotationUpdated(\(id), \(textJSON))"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script)
        }
    }

    private func removeHighlight(id: Int) {
        let script = "window.__wallinoRemoveAnnotation(\(id))"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script)
        }
    }
}

struct AnnotationEditorView: View {
    @ObservedObject var viewModel: AnnotationEditorViewModel

    var body: some View {
        NavigationView {
            Form {
                Section("Selected text") {
                    Text(viewModel.selectedText)
                }

                Section("Annotation") {
                    TextEditor(text: $viewModel.text)
                        .frame(minHeight: 120)
                }

                if viewModel.isEditing {
                    Section {
                        Button(role: .destructive) {
                            viewModel.deleteAnnotation()
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save()
                    }
                }
            }
        }
    }
}
