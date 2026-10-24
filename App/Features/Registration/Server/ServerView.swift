import SwiftUI

struct ServerView: View {
    @State private var serverViewModel = ServerViewModel()
    @Environment(\.palette) private var palette

    var body: some View {
        Form {
            Section(header: Text("Server")) {
                TextField("https://your-instance.domain", text: $serverViewModel.url)
                    .disableAutocorrection(true)
                #if os(iOS)
                    .autocapitalization(.none)
                #endif
                    .listRowBackground(palette.surface)
            }
            Button(action: {
                serverViewModel.goNext()
            }, label: {
                Text("Next")
            })
            .disabled(!serverViewModel.isValid)
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.groupedBackground)
        .navigationDestination(isPresented: $serverViewModel.shouldGoNextStep) {
            ClientIdClientSecretView()
        }
        #if os(iOS)
        .navigationBarTitle("Server")
        .navigationBarItems(trailing:
            Link(destination: Bundle.infoForKey("DOCUMENTATION_URL")!.url!) {
                Text("Open documentation")
            })
        #endif
    }
}

#if DEBUG
    struct ServerView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                ServerView()
            }
        }
    }
#endif
