@testable import Wallino_Reader
import SwiftUI
import XCTest

final class AppSettingThemeTests: XCTestCase {
    /// Keys written by AppSetting through GeneralSetting.
    private let themeKey = "theme"
    private let lightThemeKey = "lightTheme"
    private var storedTheme: String?
    private var storedLightTheme: String?

    override func setUp() {
        super.setUp()
        storedTheme = UserDefaults.standard.string(forKey: themeKey)
        storedLightTheme = UserDefaults.standard.string(forKey: lightThemeKey)
    }

    override func tearDown() {
        UserDefaults.standard.set(storedTheme, forKey: themeKey)
        UserDefaults.standard.set(storedLightTheme, forKey: lightThemeKey)
        super.tearDown()
    }

    func testSepiaAppliesWhileTheAppIsLight() {
        let setting = AppSetting()
        setting.theme = .light
        setting.lightTheme = .sepia

        XCTAssertEqual(LightTheme.sepia, setting.activeLightTheme(for: .light))
        XCTAssertEqual(ThemePalette.sepia, setting.palette(for: .light))
    }

    func testSepiaNeverAppliesWhileTheAppIsDark() {
        let setting = AppSetting()
        setting.theme = .dark
        setting.lightTheme = .sepia

        XCTAssertNil(setting.activeLightTheme(for: .dark))
        XCTAssertEqual(ThemePalette.standard, setting.palette(for: .dark))
    }

    func testAutoFollowsTheInterfaceStyle() {
        let setting = AppSetting()
        setting.theme = .auto
        setting.lightTheme = .sepia

        XCTAssertEqual(LightTheme.sepia, setting.activeLightTheme(for: .light))
        XCTAssertNil(setting.activeLightTheme(for: .dark))
    }

    func testForcedLightKeepsTheLightTheme() {
        let setting = AppSetting()
        setting.theme = .light
        setting.lightTheme = .sepia

        XCTAssertEqual(LightTheme.sepia, setting.activeLightTheme(for: .dark))
    }

    func testReaderStyleSheetFollowsTheActiveLightTheme() {
        let setting = AppSetting()
        setting.theme = .light

        setting.lightTheme = .light
        XCTAssertNil(setting.activeLightTheme(for: .light)?.articleStyleSheet)

        setting.lightTheme = .sepia
        XCTAssertEqual("sepia.css", setting.activeLightTheme(for: .light)?.articleStyleSheet)
    }
}
