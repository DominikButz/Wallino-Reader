import SwiftUI

#if os(iOS)
    import UIKit

    struct ShareableFile: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    struct ActivityView: UIViewControllerRepresentable {
        var activityItems: [Any]
        var applicationActivities: [UIActivity]?

        func makeUIViewController(context _: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        }

        func updateUIViewController(_: UIActivityViewController, context _: Context) {}
    }
#endif
