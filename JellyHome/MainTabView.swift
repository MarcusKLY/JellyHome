import SwiftUI

enum AppTab: Hashable {
    case home
    case catalog
    case library
    case admin
    case search
}

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var selectedTab: AppTab = .home
    @State private var lastNonSearchTab: AppTab = .home
    @State private var isSearchPresented = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            NavigationStack {
                CatalogView()
            }
            .tabItem {
                Label("Catalog", systemImage: "sparkles")
            }
            .tag(AppTab.catalog)

            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("Library", systemImage: "square.stack.fill")
            }
            .tag(AppTab.library)

            if session.isAdmin {
                NavigationStack {
                    AdminView()
                }
                .tabItem {
                    Label("Admin", systemImage: "shield.lefthalf.filled")
                }
                .tag(AppTab.admin)
            } else {
                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppTab.admin)
            }

            SearchTriggerView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)
        }
        .tint(Theme.accent)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .search {
                isSearchPresented = true
                selectedTab = lastNonSearchTab
            } else {
                lastNonSearchTab = newValue
            }
        }
        .sheet(isPresented: $isSearchPresented) {
            SearchView()
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

private struct SearchTriggerView: View {
    var body: some View {
        Color.clear
    }
}
