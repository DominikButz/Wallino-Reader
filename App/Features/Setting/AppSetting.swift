import Combine
import Foundation
import SharedLib
import SwiftUI

final class AppSetting: ObservableObject {
    @Published var webFontSizePercent: Double
    @Published var theme: Theme
    @Published var lightTheme: LightTheme
    @Published var autoTagNewEntry: Bool

    private var cancellable = Set<AnyCancellable>()

    init() {
        webFontSizePercent = WallabagUserDefaults.webFontSizePercent
        theme = Theme(rawValue: WallabagUserDefaults.theme) ?? .auto
        lightTheme = LightTheme(rawValue: WallabagUserDefaults.lightTheme) ?? .light
        autoTagNewEntry = WallabagUserDefaults.autoTagNewEntry

        $webFontSizePercent
            .sink(receiveValue: updateWebFontSizePercent)
            .store(in: &cancellable)

        $theme
            .sink(receiveValue: updateTheme)
            .store(in: &cancellable)

        $lightTheme
            .sink(receiveValue: updateLightTheme)
            .store(in: &cancellable)

        $autoTagNewEntry
            .sink(receiveValue: updateAutoTagNewEntry)
            .store(in: &cancellable)
    }

    private func updateWebFontSizePercent(_ value: Double) {
        WallabagUserDefaults.webFontSizePercent = value
    }

    private func updateTheme(_ value: Theme) {
        WallabagUserDefaults.theme = value.rawValue
    }

    private func updateLightTheme(_ value: LightTheme) {
        WallabagUserDefaults.lightTheme = value.rawValue
    }

    private func updateAutoTagNewEntry(_ value: Bool) {
        WallabagUserDefaults.autoTagNewEntry = value
    }

    /// The light theme in effect for the given interface style. SwiftUI has no
    /// color scheme for sepia, so it is applied whenever the app renders light
    /// and falls back to the dark appearance as soon as the app renders dark.
    func activeLightTheme(for colorScheme: ColorScheme) -> LightTheme? {
        switch theme {
        case .dark:
            return nil
        case .light:
            return lightTheme
        case .auto:
            return colorScheme == .light ? lightTheme : nil
        }
    }

    /// The palette of the active theme.
    func palette(for colorScheme: ColorScheme) -> ThemePalette {
        activeLightTheme(for: colorScheme)?.palette ?? .standard
    }
}
