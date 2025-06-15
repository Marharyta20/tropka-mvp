import SwiftUI

struct MainTabView: View {
    @State private var selection: Tab = .routes

    enum Tab {
        case explore, map, routes, tips, profile
    }

    var body: some View {
        TabView(selection: $selection) {
            ExploreView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Explore")
                }
                .tag(Tab.explore)

            MapScreenView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(Tab.map)


//            RoutesListView()
//                .tabItem {
//                    Image(systemName: "list.bullet")
//                    Text("Routes")
//                }
//                .tag(Tab.routes)

            CreatorView()
                .tabItem {
                    Image(systemName: "lightbulb")
                    Text("Tips")
                }
                .tag(Tab.tips)

            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
