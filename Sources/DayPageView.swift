import SwiftUI
import SwiftData

/// 하루(MM-DD) 데이 페이지 — 오늘 카드 + 지난 10년.
/// 기본: 애플 월렛식 peek 스택 / 탭: 연혁 펼침(선택 연도 중심).
struct DayPageView: View {
    let dateKey: String
    let anchorYear: Int

    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    @State private var editing: EditTarget?
    @State private var expanded: Bool
    @State private var focusYear: Int?

    init(dateKey: String, anchorYear: Int, initialFocusYear: Int? = nil) {
        self.dateKey = dateKey
        self.anchorYear = anchorYear
        _entries = Query(filter: #Predicate<Entry> { $0.date == dateKey }, sort: \.year)
        _focusYear = State(initialValue: initialFocusYear)
        _expanded = State(initialValue: initialFocusYear != nil)   // 캘린더에서 오면 그 연도로 펼침
    }

    private func entry(_ year: Int) -> Entry? { entries.first { $0.year == year } }
    private var filledCount: Int { entries.filter { !$0.isEmpty }.count }
    private var currentYear: Int { DiaryDate.year(Date()) }
    private var pastYears: [Int] { DiaryConfig.yearsDescending.filter { $0 < currentYear } }

    var body: some View {
        Group {
            if expanded { expandedView } else { stackView }
        }
        .background(Color.dgBackground.ignoresSafeArea())
        .fullScreenCover(item: $editing) { t in
            EntryEditorView(dateKey: t.dateKey, year: t.year)
        }
    }

    // MARK: 헤더
    private func header(showCollapse: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(DiaryDate.korean(dateKey))
                .font(.system(size: 26, weight: .heavy)).foregroundStyle(Color.dgInk)
            if let wd = DiaryDate.weekday(year: currentYear, key: dateKey) {
                Text(wd).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.dgSub)
            }
            Spacer()
            if showCollapse {
                Button { withAnimation(.snappy) { expanded = false } } label: {
                    Text("접기").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.dgInk)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Color.dgCard))
                        .overlay(Capsule().strokeBorder(Color.dgLine, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 6)
    }

    // MARK: 오늘 카드 (다크)
    private var todayCard: some View {
        let e = entry(currentYear)
        return Button { editing = EditTarget(dateKey: dateKey, year: currentYear) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(String(currentYear)) · 오늘")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.dgAccent)
                    Spacer()
                    if let m = e?.mood { Text(m.emoji).font(.system(size: 18)) }
                }
                Text((e?.text.isEmpty ?? true) ? "오늘 한 줄…" : e!.text)
                    .font(.system(size: 16))
                    .foregroundStyle((e?.text.isEmpty ?? true) ? Color.dgOnDarkSub : Color.dgOnDark)
                    .lineLimit(2).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.dgCardDark))
        }
        .buttonStyle(.plain)
    }

    // MARK: 스택 상태 (peek)
    private var stackView: some View {
        let peekH: CGFloat = 62
        let cardH: CGFloat = 92
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header(showCollapse: false)
                todayCard.padding(.horizontal, 20)

                HStack {
                    Text("지난 10년").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.dgSub)
                    Spacer()
                    Text("탭하면 펼쳐집니다").font(.system(size: 12)).foregroundStyle(Color.dgFaint)
                }
                .padding(.horizontal, 20)

                // 애플 월렛식 peek 스택 (가로폭 동일, 과거 카드가 앞에 얹혀 라벨이 보임)
                ZStack(alignment: .top) {
                    ForEach(Array(pastYears.enumerated()), id: \.element) { idx, year in
                        StackCard(year: year, yearsAgo: currentYear - year, entry: entry(year))
                            .frame(height: cardH)
                            .offset(y: CGFloat(idx) * peekH)
                            .onTapGesture {
                                focusYear = year
                                withAnimation(.snappy(duration: 0.3)) { expanded = true }
                            }
                    }
                }
                .frame(height: CGFloat(max(pastYears.count - 1, 0)) * peekH + cardH, alignment: .top)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: 펼침 상태 (연혁 타임라인 · 선택 연도 중심)
    private var expandedView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header(showCollapse: true)
                        .padding(.bottom, 8)

                    // 오늘
                    timelineRow(year: currentYear, isToday: true, isLast: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(String(currentYear)) · 오늘")
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.dgAccent)
                            todayCard
                        }
                    }
                    .id(currentYear)

                    ForEach(Array(pastYears.enumerated()), id: \.element) { idx, year in
                        timelineRow(year: year, isToday: false, isLast: idx == pastYears.count - 1) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(String(year))
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(year == focusYear ? Color.dgAccent : Color.dgInk)
                                FullYearCard(year: year, entry: entry(year), isFocused: year == focusYear) {
                                    editing = EditTarget(dateKey: dateKey, year: year)
                                }
                            }
                        }
                        .id(year)
                    }
                }
                .padding(.bottom, 40)
            }
            .onAppear {
                if let f = focusYear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.snappy) { proxy.scrollTo(f, anchor: .center) }
                    }
                }
            }
        }
    }

    /// 회사 연혁식 타임라인 행 — 좌측 세로선 + 노드, 우측 콘텐츠
    private func timelineRow<C: View>(year: Int, isToday: Bool, isLast: Bool,
                                      @ViewBuilder content: () -> C) -> some View {
        let isNode = isToday || year == focusYear
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    if isNode {
                        Circle().fill(Color.dgAccent.opacity(0.22)).frame(width: 20, height: 20)
                    }
                    Circle()
                        .fill(isNode ? Color.dgAccent : Color.dgFaint)
                        .frame(width: isNode ? 12 : 9, height: isNode ? 12 : 9)
                }
                .frame(height: 22)
                if !isLast {
                    Rectangle().fill(Color.dgLine)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 20)

            content()
                .padding(.bottom, 22)
        }
        .padding(.leading, 20).padding(.trailing, 20)
    }
}

private struct EditTarget: Identifiable {
    let dateKey: String; let year: Int
    var id: String { "\(dateKey)-\(year)" }
}

/// 스택 카드 — 상단 peek 영역에 연도 라벨 + 한 줄 요약
struct StackCard: View {
    let year: Int
    let yearsAgo: Int
    let entry: Entry?

    private var hasContent: Bool { !(entry?.isEmpty ?? true) }
    private var summary: String {
        guard let e = entry, !e.isEmpty else { return "이 해의 오늘은 아직 비어 있어요" }
        if !e.text.isEmpty { return e.text }
        return "이 날 사진 기록이 있어요"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(String(year)) · \(yearsAgo)년 전")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.dgOnDarkSub)
            Text(summary)
                .font(.system(size: 15))
                .foregroundStyle(hasContent ? Color.dgOnDark : Color.dgOnDarkSub)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.dgCardDark)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, y: -2)
    }
}

/// 펼침 카드 — 전체 텍스트 + 사진 + 기분. 선택 연도는 밝은 색으로 하이라이트.
struct FullYearCard: View {
    let year: Int
    let entry: Entry?
    let isFocused: Bool
    let onTap: () -> Void

    private var bodyColor: Color { isFocused ? Color.dgInk : Color.dgOnDark }
    private var subColor: Color { isFocused ? Color.dgSub : Color.dgOnDarkSub }

    var body: some View {
        Button(action: onTap) {
            Group {
                if let e = entry, !e.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        if !e.text.isEmpty {
                            Text(e.text)
                                .font(.system(size: 16)).foregroundStyle(bodyColor)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let data = e.photo, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        if let m = e.mood {
                            Text(m.label + (e.photo != nil ? " · 사진 1장" : ""))
                                .font(.system(size: 12)).foregroundStyle(subColor)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("이 해의 오늘은 아직 비어 있어요")
                        .font(.system(size: 15)).foregroundStyle(subColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isFocused ? Color.dgCard : Color.dgCardDark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isFocused ? Color.dgAccent : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(isFocused ? 0.10 : 0), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

/// '오늘' 탭
struct TodayView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DiaryHeader()
                DayPageView(dateKey: DiaryDate.key(Date()), anchorYear: DiaryDate.year(Date()))
            }
            .background(Color.dgBackground.ignoresSafeArea())
        }
    }
}
