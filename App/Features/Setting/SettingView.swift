import Factory
import SharedLib
import SwiftUI

struct SettingView: View {
    @AppStorage("showImageInList") var showImageInList: Bool = true
    @AppStorage("justifyArticle") var justifyArticle: Bool = true
    @AppStorage("defaultMode") var defaultMode: String = RetrieveMode.allArticles.rawValue
    @AppStorage("itemPerPageDuringSync") var itemPerPageDuringSync: Int = 50
    @AppStorage("refreshOnStartup") var refreshOnStartup: Bool = false
    @Injected(\.wallabagSession) private var session
    @EnvironmentObject var appSetting: AppSetting
    #if DEBUG
        @State private var showDeleteAllAnnotationsConfirm = false
        @State private var isDeletingAllAnnotations = false
    #endif

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appSetting.theme) {
                    ForEach(Theme.allCases) { theme in
                        Text(theme.name).tag(theme)
                    }
                }
            }
            Section("Entries list") {
                Toggle("Show image in list", isOn: $showImageInList)
                Picker("Default mode", selection: $defaultMode) {
                    ForEach(RetrieveMode.allCases, id: \.rawValue) {
                        Text($0.rawValue).tag($0.settingCase)
                    }
                }
            }
            Section("Entry") {
                Toggle("Justify entry", isOn: $justifyArticle)
            }
#if DEBUG
            Section("Annotations") {
                
                Button(role: .destructive) {
                    showDeleteAllAnnotationsConfirm = true
                } label: {
                    HStack {
                        Text("Delete All Annotations")
                        if isDeletingAllAnnotations {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeletingAllAnnotations)
                
            }
#endif
            
            Section("Sync") {
                Stepper("Items per page during sync: \(itemPerPageDuringSync)", value: $itemPerPageDuringSync, in: 20 ... 200)
                Toggle("Refresh on startup", isOn: $refreshOnStartup)
 
            }
            
            
        }
        .navigationTitle("Settings")
        .toolbar(.hidden, for: .tabBar)
        #if DEBUG
            .alert("Delete All Annotations", isPresented: $showDeleteAllAnnotationsConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    isDeletingAllAnnotations = true
                    Task {
                        await session.deleteAllAnnotations()
                        isDeletingAllAnnotations = false
                    }
                }
            } message: {
                Text("This deletes all annotations locally and on the server.")
            }
        #endif
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
            .environmentObject(AppSetting())
    }
}
