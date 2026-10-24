import SwiftUI

struct ThemeView: View {
    @EnvironmentObject var appSetting: AppSetting
    @Environment(\.palette) private var palette

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $appSetting.theme) {
                    ForEach(Theme.allCases) { theme in
                        Text(theme.name).tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .listRowBackground(palette.surface)
            }

            Section("Default Light Theme") {
                Picker("Light theme", selection: $appSetting.lightTheme) {
                    ForEach(LightTheme.allCases) { lightTheme in
                        Text(lightTheme.name).tag(lightTheme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .listRowBackground(palette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.groupedBackground)
        .navigationTitle("Theme")
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview("Sepia") {
    NavigationStack {
        ThemeView()
            .environmentObject(AppSetting())
            .environment(\.palette, .sepia)
    }
}
