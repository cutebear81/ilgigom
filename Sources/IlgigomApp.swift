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
    @AppStorage("onboardingDone") private var onboardingDone = false
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("lockMethod") private var lockMethod = "bio"
    @AppStorage("lockPIN") private var lockPIN = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var locked = false

    var body: some View {
        ZStack {
            if showSplash {
                SplashView().transition(.opacity)
            } else if !onboardingDone {
                OnboardingView { withAnimation(.easeInOut) { onboardingDone = true } }
                    .transition(.opacity)
            } else {
                RootTabView().transition(.opacity)
            }

            if locked && !showSplash {
                AppLockView(method: lockMethod, pin: lockPIN) {
                    withAnimation(.easeInOut) { locked = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .task {
            if lockEnabled { locked = true }
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && lockEnabled { locked = true }
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
        .padding(.leading, 8).padding(.trailing, 20)
    }
}
