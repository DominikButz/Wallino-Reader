import Combine
import Factory
import Foundation
import SharedLib
import SwiftUI
import WallabagKit

final class AppState: ObservableObject {
    @Injected(\.wallabagSession) private var session
    @Injected(\.appSync) private var appSync

    @Published var registred: Bool = false {
        didSet {
            WallabagUserDefaults.registred = registred
        }
    }

    @AppStorage("readingSpeed") var readingSpeed: Double = 200

    init() {
        registred = WallabagUserDefaults.registred
    }

    func initSession() async {
        if registred {
            logger.info("App state request session")

            let refreshed = await session.refreshSession()
            if !refreshed {
                await session.requestSession(clientId: WallabagUserDefaults.clientId, clientSecret: WallabagUserDefaults.clientSecret, username: WallabagUserDefaults.login, password: WallabagUserDefaults.password)
            }

            if UserDefaults.standard.bool(forKey: "refreshOnStartup") || hasPendingAutoTags() {
                await appSync.requestSync()
            }

            await fetchConfig()
        }
    }

    /// Whether entries added elsewhere (e.g. the share extension) still need to
    /// be auto-tagged. Triggers a sync so the main app can fetch them first.
    private func hasPendingAutoTags() -> Bool {
        guard #available(iOS 26.0, macOS 26.0, *) else { return false }
        return !WallabagUserDefaults.pendingAutoTagEntryIds.isEmpty
    }

    func logout() {
        logger.debug("Logout called")
        registred = false
        session.state = .unknown
    }

    /// Fetch user config from server
    /// *Require server running version 2.5*
    @MainActor
    private func fetchConfig() async {
        logger.info("Fetch user config")
        let config = try? await session.config()
        guard let config else { return }
        logger.debug("User config available")
        readingSpeed = config.readingSpeed
    }
}
