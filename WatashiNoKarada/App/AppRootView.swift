import SwiftUI

struct AppRootView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, record, scan, analysis, settings
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView(selection: $selection) }
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(Tab.home)

            NavigationStack { ManualRecordView() }
                .tabItem { Label("記録", systemImage: "square.and.pencil") }
                .tag(Tab.record)

            NavigationStack { ScanLandingView() }
                .tabItem { Label("スキャン", systemImage: "viewfinder") }
                .tag(Tab.scan)

            NavigationStack { AnalysisView() }
                .tabItem { Label("分析", systemImage: "chart.xyaxis.line") }
                .tag(Tab.analysis)

            NavigationStack { SettingsView() }
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Color.appBlue)
    }
}

extension Color {
    static let appBlue = Color(red: 0.04, green: 0.36, blue: 0.95)
    static let appTeal = Color(red: 0.02, green: 0.78, blue: 0.72)
    static let appMint = Color(red: 0.30, green: 0.92, blue: 0.60)
}
