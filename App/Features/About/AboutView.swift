import SwiftUI

struct AboutView: View {
    @BundleKey("CFBundleShortVersionString")
    var version: String

    @BundleKey("CFBundleVersion")
    var build: String
    
    @BundleKey("CFBundleDisplayName")
    var displayName

    var body: some View {
        VStack {
            Text(displayName).font(.largeTitle).fontWeight(.bold)
            Text(String(format: "Version %@ build %@".localized, arguments: [version, build]))
            Spacer()
            Link("Project page", destination: "https://github.com/DominikButz/Wallino-Reader")
            Spacer()
         
            VStack(spacing: 10) {
                Text("Created by Dominik Butz").font(.body)
                Text("Based on Maxime Marinel's Wallabag for iOS").font(.callout).italic()
                Text("Special Thanks").font(.callout).italic()
            }
        }
        .navigationTitle("About")
    }
}

#Preview {
    AboutView()
}
