import SwiftUI

/// Semantic colors for the app surfaces. The standard palette uses dynamic
/// system colors so it keeps working in dark mode, while the sepia palette is a
/// fixed light appearance and is only applied when the app renders light.
struct ThemePalette: Equatable {
    /// Background of plain screens and of the app itself.
    let background: Color
    /// Background of grouped forms, behind their cards.
    let groupedBackground: Color
    /// Card and list row background.
    let surface: Color
    /// Small chips such as the entry tags.
    let chipBackground: Color

    /// Matches the Sepia asset and the paper tone used by the article reader in
    /// sepia.css (#F4ECD8).
    static let sepiaBackground = Color("Sepia")

    static let standard = ThemePalette(
        background: Color(uiColor: .systemBackground),
        groupedBackground: Color(uiColor: .systemGroupedBackground),
        surface: Color(uiColor: .secondarySystemGroupedBackground),
        chipBackground: Color(uiColor: .quaternarySystemFill)
    )

    static let sepia = ThemePalette(
        background: sepiaBackground,
        groupedBackground: sepiaBackground,
        surface: Color(red: 0.980, green: 0.953, blue: 0.890),
        chipBackground: Color(red: 0.478, green: 0.416, blue: 0.337).opacity(0.25)
    )
}

extension ThemePalette: EnvironmentKey {
    static var defaultValue: ThemePalette { .standard }
}

extension EnvironmentValues {
    /// The color palette of the active app theme.
    var palette: ThemePalette {
        get { self[ThemePalette.self] }
        set { self[ThemePalette.self] = newValue }
    }
}
