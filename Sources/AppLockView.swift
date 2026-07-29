import SwiftUI
import LocalAuthentication

/// 앱 잠금 화면 — 생체(Face ID/Touch ID) 또는 PIN(비밀번호).
struct AppLockView: View {
    let method: String     // "bio" | "pin"
    let pin: String
    let onUnlock: () -> Void

    @State private var input = ""
    @State private var wrong = false
    @State private var bioTried = false

    var body: some View {
        ZStack {
            Color.dgBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image("AppLogo").resizable().scaledToFit().frame(height: 70)
                Text("일기곰이 잠겨 있어요")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(Color.dgInk)

                if method == "pin" {
                    pinPad
                } else {
                    Button {
                        authenticateBio()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "faceid").font(.system(size: 18))
                            Text("Face ID로 잠금 해제").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 14)
                        .background(Capsule().fill(Color.dgAccent))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear { if method == "bio" && !bioTried { authenticateBio() } }
    }

    // MARK: 생체 인증
    private func authenticateBio() {
        bioTried = true
        let ctx = LAContext()
        var err: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            ctx.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "일기곰 잠금을 해제합니다") { ok, _ in
                if ok { DispatchQueue.main.async { onUnlock() } }
            }
        }
    }

    // MARK: PIN 패드
    private var pinPad: some View {
        VStack(spacing: 22) {
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < input.count ? Color.dgAccent : Color.clear)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(Color.dgSub, lineWidth: 1.5))
                }
            }
            .modifier(Shake(animatableData: wrong ? 1 : 0))

            let keys = ["1","2","3","4","5","6","7","8","9","","0","⌫"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 18) {
                ForEach(keys, id: \.self) { k in
                    if k.isEmpty { Color.clear.frame(height: 60) }
                    else {
                        Button { tap(k) } label: {
                            Text(k).font(.system(size: 26, weight: .medium))
                                .foregroundStyle(Color.dgInk)
                                .frame(maxWidth: .infinity).frame(height: 60)
                        }
                    }
                }
            }
        }
    }

    private func tap(_ k: String) {
        if k == "⌫" { if !input.isEmpty { input.removeLast() }; return }
        guard input.count < 4 else { return }
        input += k
        if input.count == 4 {
            if input == pin { onUnlock() }
            else {
                withAnimation(.default) { wrong.toggle() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { input = "" }
            }
        }
    }
}

/// PIN 오류 흔들기 애니메이션
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
