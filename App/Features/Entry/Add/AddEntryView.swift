import SharedLib
import SwiftUI

struct AddEntryView: View {
    @State private var model = AddEntryModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case url
        case text
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

    var body: some View {
        Form {
            Picker("Add entry", selection: $model.mode) {
                Text("Url").tag(AddEntryMode.url)
                Text("Text").tag(AddEntryMode.text)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))

            if model.mode == .url {
                TextField("Url", text: $model.input)
                #if os(iOS)
                    .autocapitalization(.none)
                #endif
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .url)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .overlay(inputOutline(isFocused: focusedField == .url))
            } else {
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

                    TextField("Domain name, e.g. newspaper.com (optional)", text: $model.domainName)
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
            .disabled(model.input.isEmpty)
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .animation(.easeInOut, value: model.succeeded)
        .animation(.easeInOut, value: model.submitting)
        .navigationTitle("Add entry")
    }
}

#Preview {
    AddEntryView()
}
