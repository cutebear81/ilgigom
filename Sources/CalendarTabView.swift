import SwiftUI
import SwiftData

/// 캘린더에서 데이 페이지로 이동할 때 넘기는 경로 (선택 연·월일)
struct DayRoute: Hashable {
    let dateKey: String
    let year: Int
}

/// 캘린더 탭 — 연도 선택 + 월간 그리드(작성일 오렌지). 날짜 탭 → 데이 페이지.
struct CalendarTabView: View {
    @Query private var allEntries: [Entry]
    @State private var year = DiaryDate.year(Date())
    @State private var month = Calendar.current.component(.month, from: Date())

    private let cal = Calendar.current
    private let weekdays = ["일","월","화","수","목","금","토"]

    /// 선택 연도에서 기록이 있는 날짜키 집합
    private var filledKeys: Set<String> {
        Set(allEntries.filter { $0.year == year && !$0.isEmpty }.map { $0.date })
    }

    private func key(_ day: Int) -> String { String(format: "%02d-%02d", month, day) }

    private var daysInMonth: Int {
        var c = DateComponents(); c.year = year; c.month = month
        guard let d = cal.date(from: c),
              let range = cal.range(of: .day, in: .month, for: d) else { return 30 }
        return range.count
    }
    private var firstWeekday: Int {
        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        guard let d = cal.date(from: c) else { return 1 }
        return cal.component(.weekday, from: d) // 1=일
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DiaryHeader()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        yearStrip
                        monthHeader
                        grid
                        Text("색이 진할수록 그 날의 기록이에요")
                            .font(.system(size: 11)).foregroundStyle(Color.dgSub)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 30)
                }
            }
            .background(Color.dgBackground.ignoresSafeArea())
            .navigationDestination(for: DayRoute.self) { route in
                VStack(spacing: 0) {
                    DiaryHeader()
                    DayPageView(dateKey: route.dateKey, anchorYear: route.year, initialFocusYear: route.year)
                }
                .background(Color.dgBackground.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var yearStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiaryConfig.yearsDescending, id: \.self) { y in
                    Button { withAnimation(.snappy) { year = y } } label: {
                        Text(String(y))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(y == year ? .white : Color.dgSub)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(y == year ? Color.dgAccent : Color.dgCard, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.dgLine, lineWidth: y == year ? 0 : 1))
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
            }.foregroundStyle(Color.dgInk)
            Spacer()
            Text("\(month)월").font(.system(size: 20, weight: .heavy)).foregroundStyle(Color.dgInk)
            Spacer()
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold))
            }.foregroundStyle(Color.dgInk)
        }
        .padding(.horizontal, 8)
    }

    private var grid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(weekdays, id: \.self) { w in
                Text(w).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(w == "일" ? Color.dgAccent : Color.dgSub)
            }
            ForEach(0 ..< (firstWeekday - 1), id: \.self) { _ in Color.clear.frame(height: 40) }
            ForEach(1 ... daysInMonth, id: \.self) { day in
                let filled = filledKeys.contains(key(day))
                NavigationLink(value: DayRoute(dateKey: key(day), year: year)) {
                    Text("\(day)")
                        .font(.system(size: 14, weight: filled ? .bold : .regular))
                        .foregroundStyle(filled ? .white : Color.dgInk)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(
                            Circle().fill(filled ? Color.dgAccent : Color.dgCard)
                                .frame(width: 36, height: 36)
                        )
                }
            }
        }
    }

    private func changeMonth(_ delta: Int) {
        var m = month + delta
        if m < 1 { m = 12 }; if m > 12 { m = 1 }
        withAnimation(.snappy) { month = m }
    }
}
