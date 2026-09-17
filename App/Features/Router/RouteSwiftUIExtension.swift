//
//  RouteSwiftUIExtension.swift
//  wallabag (iOS)
//
//  Created by maxime marinel on 13/03/2023.
//

import Foundation
import SwiftUI

extension View {
    func appRouting() -> some View {
        navigationDestination(for: RoutePath.self) { route in
            switch route {
            case .addEntry:
                AddEntryView()
            case let .entry(entry):
                EntryView(entry: entry)
            case let .entriesForTag(tag):
                EntriesForTagView(tag: tag)
            case .about:
                AboutView()
            case .terms:
                HTMLViewerContainerView(fileName: "terms", navTitle: "Terms and Conditions")
            case .privacy:
                HTMLViewerContainerView(fileName: "privacy", navTitle: "Privacy Policy")
            case .accountLogout:
                LogoutView()
            case .tips:
                TipView()
            case .setting:
                SettingView()
            case .registration:
                RegistrationView()
            
            }
        }
    }
}
