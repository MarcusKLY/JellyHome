//
//  ContentView.swift
//  JellyHome
//
//  Created by Kam Long Yin on 10/5/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        if session.isAuthenticated {
            MainTabView()
        } else {
            ConnectView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
}
