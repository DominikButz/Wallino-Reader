import SwiftUI

/// Injects the palette of the active light theme and paints the app background.
/// The interface style is read from the environment so that `.preferredColorScheme`
/// and the system appearance are respected: sepia never applies in dark mode.
struct ThemeSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appSetting: AppSetting

    func body(content: Content) -> some View {
        content
            .environment(\.palette, palette)
            .background(palette.background)
    }

    private var palette: ThemePalette {
        appSetting.palette(for: colorScheme)
    }
}

extension View {
    /// Applies the app color theme. Keep this after `preferredColorScheme(_:)`.
    func themed() -> some View {
        modifier(ThemeSurface())
    }
}
