import SwiftUI

/// The light appearance used whenever the app renders light. SwiftUI only
/// knows `ColorScheme.light`, so the variants differ in their `ThemePalette`
/// and in the article stylesheet instead of their color scheme.
enum LightTheme: String, CaseIterable, Identifiable {
    case light
    case sepia

    var id: String { rawValue }

    var palette: ThemePalette {
        switch self {
        case .light:
            return .standard
        case .sepia:
            return .sepia
        }
    }

    /// Extra stylesheet for the article reader, nil keeps the default look.
    var articleStyleSheet: String? {
        switch self {
        case .light:
            return nil
        case .sepia:
            return "sepia.css"
        }
    }

    var name: LocalizedStringResource {
        switch self {
        case .light:
            return LocalizedStringResource("Light")
        case .sepia:
            return LocalizedStringResource("Sepia")
        }
    }
}
