import Foundation
import SwiftUI

struct FontSizeSelectorView: View {
    @State private var showSelector = false
    @EnvironmentObject var appSetting: AppSetting

    var body: some View {
        Button(action: {
            showSelector = true
        }, label: {
            Image(systemName: "textformat.size")
        })
        .accessibilityLabel("Text size")
        .accessibilityHint("Change entry text size")
        .sheet(isPresented: $showSelector) {
            VStack(spacing: 16) {
                HStack {
                    Text("Text size")
                    Spacer()
                    Text("\(Int(appSetting.webFontSizePercent))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size.smaller")
                        .foregroundStyle(.secondary)
                    Slider(value: $appSetting.webFontSizePercent, in: 50 ... 200, step: 10)
                        .accessibilityLabel("Text size")
                        .accessibilityHint("Change entry text size")
                    Image(systemName: "textformat.size.larger")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .presentationDetents([.height(150)])
            .presentationDragIndicator(.visible)
        }
    }
}
