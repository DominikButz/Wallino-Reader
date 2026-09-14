import Factory
import Foundation
import os
import SwiftUI

let logger = Logger(subsystem: "com.duoyun.wallino-reader", category: "main")

@main
struct WallinoApp: App {
    @Environment(\.scenePhase) var scenePhase
    #if os(iOS)
        @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @State private var router = Container.shared.router()
    @State private var appSync = Container.shared.appSync()
    @State private var errorHandler = Container.shared.errorHandler()

    @InjectedObject(\.appState) private var appState
    #if os(iOS)
        @State private var playerPublisher = Container.shared.playerPublisher()
    #endif
    @InjectedObject(\.appSetting) private var appSetting
    @Injected(\.coreDataSync) private var coreDataSync
    @Injected(\.coreData) private var coreData

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
            #if os(iOS)
                .environment(playerPublisher)
            #endif
                .environment(router)
                .environment(appSync)
                .environment(errorHandler)
                .environmentObject(appSetting)
                .environment(\.managedObjectContext, coreData.viewContext)
                .preferredColorScheme(appSetting.theme.colorScheme)
        }
        .onChange(of: scenePhase) { _, newScenePhase in
            if newScenePhase == .active {
                Task {
                    await appState.initSession()
                }
            }

            if newScenePhase == .background {
                coreData.saveContext()
            }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh entries") {
                    appSync.requestSync()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
