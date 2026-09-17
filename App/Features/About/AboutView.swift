import SwiftUI

struct AboutView: View {
    @Environment(Router.self) var router: Router
    @BundleKey("CFBundleShortVersionString")
    var version: String

    @BundleKey("CFBundleVersion")
    var build: String
    
    @BundleKey("CFBundleDisplayName")
    var displayName

    var body: some View {
        @Bindable var router = router
        VStack {
            Text(displayName).font(.largeTitle).fontWeight(.bold)
            Text(String(format: "Version %@ build %@".localized, arguments: [version, build]))
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                Link(destination: URL(string: "https://github.com/DominikButz/Wallino-Reader")!) {
                    Label("Project page".localized, systemImage: "arrow.up.forward")
                }
                Button {
                    router.path.append(RoutePath.terms)
                } label: {
                    Label("Terms & Conditions", systemImage: "doc.text")
                }
                Button {
                    router.path.append(RoutePath.privacy)
                } label: {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }
            }.font(.system(.headline))
            Spacer()
         
            VStack(spacing: 10) {
                Text("Forked & developed by Dominik Butz").font(.body)
                Text("Based on Maxime Marinel's Wallabag for iOS".localized).font(.callout).italic()
            }
        }
        .navigationTitle("About")
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    AboutView()
        .environment(Router())
}
