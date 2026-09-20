import XCTest

final class WallinoReaderUITests: XCTestCase {

    var app: XCUIApplication!
    private var detectedLocale: String?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-skipLogin")
        app.launchArguments.append("-uiTesting")
    }

    @MainActor
    private func launchApp() {
        app.launch()
        detectedLocale = Self.localeFromUITab(app)
    }

    /// Detects the app's language from the localized "Entries" tab label, so the
    /// language only has to be set in the scheme's Run action (App Language).
    @MainActor
    private static func localeFromUITab(_ app: XCUIApplication) -> String? {
        let entriesTab = app.tabBars.buttons.element(boundBy: 0)
        guard entriesTab.waitForExistence(timeout: 15) else { return nil }
        switch entriesTab.label {
        case "Einträge": return "de-DE"
        case "Articles": return "fr-FR"
        case "Entries": return "en-US"
        default: return nil
        }
    }

    private func tapFirstEntry() {
        let entryList = app.collectionViews["entry_list"]
        let firstEntry = entryList.cells.firstMatch
        guard firstEntry.waitForExistence(timeout: 30) else { return }
        firstEntry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(3)
    }

    @MainActor
    private func waitForEntryDetail() {
        _ = app.buttons["entry_option_menu"].waitForExistence(timeout: 15)
        sleep(5)
    }

    // MARK: - Screenshots

    private var projectDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Returns the fastlane-style locale folder (e.g. "en-US") for this run.
    /// Priority: detected app language -> SNAPSHOT_LOCALE env -> scheme/system language.
    @MainActor
    private var screenshotLocale: String {
        let candidates: [String?] = [
            detectedLocale,
            ProcessInfo.processInfo.environment["SNAPSHOT_LOCALE"],
            UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first,
            Locale.current.identifier,
        ]
        for case let candidate? in candidates where !candidate.isEmpty {
            return Self.normalizedLocale(candidate)
        }
        return "en-US"
    }

    private static func normalizedLocale(_ code: String) -> String {
        let lower = code.lowercased()
        if lower.hasPrefix("de") { return "de-DE" }
        if lower.hasPrefix("fr") { return "fr-FR" }
        if lower.hasPrefix("en") { return "en-US" }
        return code
    }

    private func localizedDeviceName() -> String {
        var device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "unknown"
        if let regex = try? NSRegularExpression(pattern: "Clone [0-9]+ of ") {
            let range = NSRange(device.startIndex..., in: device)
            device = regex.stringByReplacingMatches(in: device, range: range, withTemplate: "")
        }
        return device
    }

    /// Saves a plain screenshot to ./media/screenshots/<locale>/<device>-<name> plain.png
    @MainActor
    private func takeScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let locale = screenshotLocale
        let directory = projectDirectory
            .appendingPathComponent("media/screenshots")
            .appendingPathComponent(locale)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(localizedDeviceName())-\(name) plain.png")
        try? screenshot.pngRepresentation.write(to: url)
        print("Plain screenshot saved: \(url.path) (locale=\(locale))")
    }

    // MARK: - Tests

    @MainActor
    func testEntryList() throws {
        launchApp()
        let entryList = app.collectionViews["entry_list"]
        XCTAssertTrue(entryList.waitForExistence(timeout: 30))
        sleep(3)
        takeScreenshot("01_EntryList")
    }

    @MainActor
    func testEntryDetail() throws {
        launchApp()
        tapFirstEntry()
        waitForEntryDetail()
        takeScreenshot("02_EntryDetail")
    }

    @MainActor
    func testEntryDetailMenu() throws {
        launchApp()
        tapFirstEntry()

        let menuButton = app.buttons["entry_option_menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 15))
        menuButton.tap()

        sleep(1)
        takeScreenshot("03_EntryDetailMenu")
    }

    @MainActor
    func testEntryDetailAI() throws {
        launchApp()
        tapFirstEntry()
        sleep(2)
        let aiButton = app.buttons["ai_actions_menu"]
        guard aiButton.waitForExistence(timeout: 15) else {
            print("AI actions menu not available on this device/iOS version")
            return
        }
        aiButton.tap()

        sleep(1)
        takeScreenshot("04_EntryDetailAI")
    }

    @MainActor
    func testTagsList() throws {
        launchApp()
        let tagsTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(tagsTab.waitForExistence(timeout: 15))
        tagsTab.tap()

        let tagsList = app.collectionViews["tags_list"]
        XCTAssertTrue(tagsList.waitForExistence(timeout: 15))
        sleep(2)
        takeScreenshot("05_TagsList")
    }
}
