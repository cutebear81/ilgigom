import SwiftUI

// 오프닝 로딩 화면 — 로고 중앙 + 바로 아래 한마디
struct SplashView: View {
    private let off = Color(red: 0.969, green: 0.957, blue: 0.937)   // #F7F4EF
    private let sub = Color(red: 0.54, green: 0.50, blue: 0.45)

    var body: some View {
        ZStack {
            off.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable().scaledToFit()
                    .frame(width: 150)
                Text("하루 한 줄, 10년의 오늘")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(sub)
            }
        }
    }
}

#Preview { SplashView() }
