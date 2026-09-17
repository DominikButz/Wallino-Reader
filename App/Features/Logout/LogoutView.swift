//
//  LogoutView.swift
//  Wallino Reader
//
//  Created by Dominik Butz on 8/9/2026.
//

import SharedLib
import SwiftUI

struct LogoutView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Label {
                    Text("Username:").font(Font.body.bold())
                } icon: {
                    Image(systemName: "person.circle")
                }
                
                HStack {
                    Text(WallabagUserDefaults.login)
                }
            }
            
            Divider()
            Button(role: .destructive, action: {
                appState.logout()
            }, label: {
                Label("Logout", systemImage: "person")
            }).foregroundColor(.red)
                .controlSize(.large)
            
            Spacer()
            
        }.navigationTitle("Account Logout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        
    }
}

#Preview {
    LogoutView()
}
