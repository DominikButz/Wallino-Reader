import SharedLib
import SwiftUI
import UniformTypeIdentifiers

struct AddEntryView: View {
    @State private var model = AddEntryModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focusedField: Field?
    @State private var showPDFImporter = false

    private enum Field: Hashable {
        case url
        case text
        case pdfTitle
        case domainName
    }

    private var textEditorHeight: CGFloat {
        horizontalSizeClass == .regular ? 320 : 180
    }

    private func inputOutline(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                isFocused ? Color.accentColor : Color.secondary.opacity(0.3),
                lineWidth: isFocused ? 2 : 1
            )
    }

    private var domainNameField: some View {
        TextField("Domain name, e.g. news.com (optional)", text: $model.domainName)
        #if os(iOS)
            .autocapitalization(.none)
            .keyboardType(.URL)
        #endif
            .disableAutocorrection(true)
            .focused($focusedField, equals: .domainName)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .overlay(inputOutline(isFocused: focusedField == .domainName))
    }

    private var pdfImportProgressLabel: String {
        if model.pdfProgressTotal > 1 {
            return String(format: "Converting PDF… page %d of %d".localized, arguments: [model.pdfProgressPage, model.pdfProgressTotal])
        }
        return "Converting PDF…".localized
    }

    var body: some View {
        Form {
            Picker("Add entry", selection: $model.mode) {
                Text("Url").tag(AddEntryMode.url)
                Text("Text").tag(AddEntryMode.text)
                Text("PDF").tag(AddEntryMode.pdf)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))

            switch model.mode {
            case .url:
                TextField("Url", text: $model.input)
                #if os(iOS)
                    .autocapitalization(.none)
                #endif
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .url)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .overlay(inputOutline(isFocused: focusedField == .url))
            case .text:
                VStack(alignment: .leading, spacing: 10) {
                    Color.clear
                        .frame(height: textEditorHeight)
                        .overlay(alignment: .topLeading) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $model.input)
                                    .scrollContentBackground(.hidden)
                                    .focused($focusedField, equals: .text)

                                if model.input.isEmpty {
                                    Text("Text")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(inputOutline(isFocused: focusedField == .text))

                    domainNameField
                }
            case .pdf:
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        showPDFImporter = true
                    } label: {
                        Label("Import PDF", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.pdfImporting)

                    if let fileName = model.pdfFileName {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "doc.richtext.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileName)
                                    .lineLimit(2)

                                if model.pdfPageCount > 0 {
                                    Text(String(format: "%d pages".localized, arguments: [model.pdfPageCount]))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                model.clearPDF()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove PDF"))
                            .disabled(model.pdfImporting)
                        }
                    }

                    if model.pdfImporting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(pdfImportProgressLabel)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let pdfError = model.pdfError {
                        Text(pdfError)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    if model.pdfTitleReady {
                        TextField("Title", text: $model.pdfTitle)
                            .focused($focusedField, equals: .pdfTitle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .overlay(inputOutline(isFocused: focusedField == .pdfTitle))
                    }

                    domainNameField
                }
            }

            HStack {
                if model.succeeded {
                    if model.addedCount > 1 {
                        Text(String(format: "Great! %d entries were added".localized, arguments: [model.addedCount]))
                    } else {
                        Text("Great! Entry was added")
                    }
                } else {
                    Button(model.submitting ? "Submitting..." : "Submit") {
                        Task {
                            await model.addEntry()
                        }
                    }.disabled(model.submitting)
                }
            }
            .disabled(!model.canSubmit)
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .animation(.easeInOut, value: model.succeeded)
        .animation(.easeInOut, value: model.submitting)
        .animation(.easeInOut, value: model.pdfImporting)
        .animation(.easeInOut, value: model.pdfFileName)
        .navigationTitle("Add entry")
        .fileImporter(
            isPresented: $showPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                Task {
                    await model.importPDF(from: url)
                }
            case let .failure(error):
                model.pdfError = error.localizedDescription
            }
        }
        .confirmationDialog(
            "The PDF is too long",
            isPresented: $model.showTruncationConfirmation,
            titleVisibility: .visible
        ) {
            Button("Import partial text") {
                model.confirmTruncatedImport()
            }
            Button("Cancel", role: .cancel) {
                model.cancelTruncatedImport()
            }
        } message: {
            if let pending = model.pendingTruncation {
                Text(
                    String(
                        format: "Only the first %d of %d characters of the PDF text will be imported".localized,
                        arguments: [pending.importedCharacterCount, pending.totalCharacterCount]
                    )
                )
            }
        }
    }
}

#Preview {
    AddEntryView()
}
