import Combine
import Foundation
import SharedLib

final class AppSetting: ObservableObject {
    @Published var webFontSizePercent: Double
    @Published var theme: Theme
    @Published var autoTagNewEntry: Bool

    private var cancellable = Set<AnyCancellable>()

    init() {
        webFontSizePercent = WallabagUserDefaults.webFontSizePercent
        theme = Theme(rawValue: WallabagUserDefaults.theme) ?? .auto
        autoTagNewEntry = WallabagUserDefaults.autoTagNewEntry

        $webFontSizePercent
            .sink(receiveValue: updateWebFontSizePercent)
            .store(in: &cancellable)

        $theme
            .sink(receiveValue: updateTheme)
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

    private func updateAutoTagNewEntry(_ value: Bool) {
        WallabagUserDefaults.autoTagNewEntry = value
    }
}
