import SwiftUI

struct LoginView: View {
    @State var loginViewModel = LoginViewModel()
    @Environment(\.palette) private var palette

    var body: some View {
        Form {
            Section(header: Text("Login")) {
                TextField("Login", text: $loginViewModel.login)
                #if os(iOS)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                #endif
                    .listRowBackground(palette.surface)
            }
            Section(header: Text("Password")) {
                SecureField("Password", text: $loginViewModel.password)
                    .listRowBackground(palette.surface)
            }
            Button("Login") {
                Task {
                    await loginViewModel.tryLogin()
                }
            }
            .disabled(!loginViewModel.isValid)
            .listRowBackground(palette.surface)
            if let error = loginViewModel.error {
                VStack {
                    Text(error).foregroundColor(.red)
                    Link("Report issue", destination: "https://github.com/DominikButz/Wallino-Reader/issues")
                }
                .listRowBackground(palette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.groupedBackground)
        #if os(iOS)
        .navigationBarTitle("Login & Password")
        .navigationBarItems(trailing:
            Link(destination: Bundle.infoForKey("DOCUMENTATION_URL")!.url!) {
                Text("Open documentation")
            })
        #endif
    }
}

#if DEBUG
    struct LoginView_Previews: PreviewProvider {
        static var previews: some View {
            LoginView()
        }
    }
#endif
