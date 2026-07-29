import SwiftUI
import SwiftData

@main
struct IlgigomApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: Entry.self)
    }
}

struct RootView: View {
    @State private var showSplash = true
    var body: some View {
        ZStack {
            if showSplash {
                SplashView().transition(.opacity)
            } else {
                RootTabView().transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
        }
    }
}

struct RootTabView: View {
    init() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Color.dgBackground)
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("오늘", systemImage: "book.closed") }
            CalendarTabView()
                .tabItem { Label("캘린더", systemImage: "calendar") }
            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
        .tint(.dgAccent)
    }
}

// 콘텐츠 헤더 (곰 로고 — 네비바 대신 콘텐츠 상단, height 72)
struct DiaryHeader: View {
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            Image("AppLogo").resizable().scaledToFit().frame(height: 66)
            Spacer()
            if let trailing { trailing }
        }
        .frame(height: 72)
        .padding(.horizontal, 20)
    }
}
