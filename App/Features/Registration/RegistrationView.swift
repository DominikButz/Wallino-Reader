import SwiftUI

struct RegistrationView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150)
                Text("Wallino Reader")
                    .font(.title)
                NavigationLink("Log in", destination: ServerView())
                    .buttonStyle(.borderedProminent)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
    }
}

#Preview {
    RegistrationView()
}
