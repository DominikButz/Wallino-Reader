import Foundation

/// The App Group used to share data with the share extension. Debug builds use
/// a separate group so debug and production never share data.
public enum WallabagAppGroup {
    public static var identifier: String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        return bundleIdentifier.contains(".debug")
            ? "group.com.duoyun.wallino-reader.debug"
            : "group.com.duoyun.wallino-reader"
    }
}

public enum WallabagUserDefaults {
    @Setting("host", defaultValue: "")
    public static var host: String

    @Setting("clientId", defaultValue: "")
    public static var clientId: String

    @Setting("clientSecret", defaultValue: "")
    public static var clientSecret: String

    @Setting("username", defaultValue: "")
    public static var login: String

    @Password()
    public static var password: String

    @Setting("registred", defaultValue: false)
    public static var registred: Bool

    @Setting("accessToken", defaultValue: nil)
    public static var accessToken: String?

    @Setting("refreshToken", defaultValue: nil)
    public static var refreshToken: String?

    @Setting("expiresIn", defaultValue: nil)
    public static var expiresIn: Int?

    @Setting("previousPasteBoardUrl", defaultValue: "")
    public static var previousPasteBoardUrl: String

    @GeneralSetting("justifyArticle", defaultValue: true)
    public static var justifyArticle: Bool

    @GeneralSetting("defaultMode", defaultValue: "allArticles")
    public static var defaultMode: String

    @Setting("webFontSizePercent", defaultValue: 100)
    public static var webFontSizePercent: Double

    @GeneralSetting("showImageInList", defaultValue: true)
    public static var showImageInList: Bool

    @GeneralSetting("itemPerPageDuringSync", defaultValue: 50)
    public static var itemPerPageDuringSync: Int

    @GeneralSetting("theme", defaultValue: "auto")
    public static var theme: String
}
