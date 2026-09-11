import SharedLib
import SwiftUI

struct AddEntryView: View {
    @State private var model = AddEntryModel()

    var body: some View {
        Form {
            TextField("Url", text: $model.url)
            #if os(iOS)
                .autocapitalization(.none)
            #endif
                .disableAutocorrection(true)
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
            .disabled(model.url.isEmpty)
        }
        .animation(.easeInOut, value: model.succeeded)
        .animation(.easeInOut, value: model.submitting)
        .navigationTitle("Add entry")
    }
}

#Preview {
    AddEntryView()
}
