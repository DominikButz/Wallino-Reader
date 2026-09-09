import SwiftUI

struct AboutView: View {
    @BundleKey("CFBundleShortVersionString")
    var version: String

    @BundleKey("CFBundleVersion")
    var build: String

    var body: some View {
        VStack {
            Text("Wallino Reader").font(.largeTitle).fontWeight(.bold)
            Text(String(format: "Version %@ build %@".localized, arguments: [version, build]))
            Spacer()
            Link("Project page", destination: "https://github.com/DominikButz/Wallino-Reader")
            Spacer()
            Text("Made by Dominik Butz")
        }
        .navigationTitle("About")
    }
}

#Preview {
    AboutView()
}
