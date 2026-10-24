import SharedLib
import SwiftUI

struct ClientIdClientSecretView: View {
    @State private var clientIdSecretViewModel = ClientIdSecretViewModel()
    @Environment(\.palette) private var palette

    var body: some View {
        Form {
            Section(header: Text("Client id")) {
                TextField("Client id", text: $clientIdSecretViewModel.clientId)
                    .disableAutocorrection(true)
                #if os(iOS)
                    .autocapitalization(.none)
                #endif
                    .listRowBackground(palette.surface)
            }
            Section(header: Text("Client secret")) {
                TextField("Client secret", text: $clientIdSecretViewModel.clientSecret)
                    .disableAutocorrection(true)
                #if os(iOS)
                    .autocapitalization(.none)
                #endif
                    .listRowBackground(palette.surface)
            }
            Button(action: {
                clientIdSecretViewModel.goNext()
            }, label: {
                Text("Next")
            })
            .disabled(!clientIdSecretViewModel.isValid)
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.groupedBackground)
        .navigationDestination(isPresented: $clientIdSecretViewModel.shouldGoNextStep) {
            LoginView()
        }
        #if os(iOS)
        .navigationBarTitle("Client id & secret")
        .navigationBarItems(trailing:
            Link(destination: Bundle.infoForKey("DOCUMENTATION_URL")!.url!) {
                Text("Open documentation")
            })
        #endif
    }
}

#Preview {
    NavigationView {
        ClientIdClientSecretView()
    }
}
