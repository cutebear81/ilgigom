import SwiftUI

/// 첫 실행 온보딩 — 핵심 사용법 도움말.
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    private struct Page { let emoji: String; let title: String; let desc: String }
    private let pages: [Page] = [
        Page(emoji: "🐻", title: "하루 한 줄, 10년의 오늘",
             desc: "오늘을 기록하면 지난 10년의 같은 날이\n한자리에 나란히 쌓여요."),
        Page(emoji: "✏️", title: "오늘 한 줄이면 충분해요",
             desc: "글·사진·기분, 그리고 그날의 위치·날씨까지\n버튼 한 번으로 자유롭게 남겨요."),
        Page(emoji: "🔖", title: "해시태그로 다시 만나요",
             desc: "해시태그나 단어로 지난 일기를\n날짜별로 언제든 검색해요."),
        Page(emoji: "📅", title: "오늘부터 시작해요",
             desc: "매일 알림으로 잊지 않게.\n지금 첫 한 줄을 남겨볼까요?"),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.dgBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // 스킵
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("건너뛰기") { onDone() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.dgSub)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                        VStack(spacing: 20) {
                            Spacer()
                            Text(p.emoji).font(.system(size: 92))
                            Text(p.title)
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(Color.dgInk)
                                .multilineTextAlignment(.center)
                            Text(p.desc)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.dgSub)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                            Spacer()
                        }
                        .padding(.horizontal, 32)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                // 하단 버튼
                Button {
                    if page < pages.count - 1 {
                        withAnimation(.snappy) { page += 1 }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "다음" : "시작하기")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.dgAccent))
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
    }
}
