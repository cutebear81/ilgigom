import SwiftUI

/// 4자리 PIN 설정 — 입력 후 확인 재입력.
struct PinSetupView: View {
    let onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var first = ""
    @State private var confirm = ""
    @State private var stage = 0   // 0: 새 PIN, 1: 확인
    @State private var wrong = false

    private var current: String { stage == 0 ? first : confirm }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dgBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    Text(stage == 0 ? "새 비밀번호 4자리" : "한 번 더 입력")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(Color.dgInk)
                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(i < current.count ? Color.dgAccent : Color.clear)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(Color.dgSub, lineWidth: 1.5))
                        }
                    }
                    .modifier(Shake(animatableData: wrong ? 1 : 0))
                    Spacer()
                    pad
                }
                .padding(.horizontal, 40).padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.foregroundStyle(Color.dgInk)
                }
            }
        }
    }

    private var pad: some View {
        let keys = ["1","2","3","4","5","6","7","8","9","","0","⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 18) {
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

    private func tap(_ k: String) {
        if k == "⌫" {
            if stage == 0 { if !first.isEmpty { first.removeLast() } }
            else { if !confirm.isEmpty { confirm.removeLast() } }
            return
        }
        if stage == 0 {
            guard first.count < 4 else { return }
            first += k
            if first.count == 4 { stage = 1 }
        } else {
            guard confirm.count < 4 else { return }
            confirm += k
            if confirm.count == 4 {
                if confirm == first { onDone(first); dismiss() }
                else {
                    withAnimation(.default) { wrong.toggle() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        confirm = ""; first = ""; stage = 0
                    }
                }
            }
        }
    }
}
