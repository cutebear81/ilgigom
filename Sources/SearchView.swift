import SwiftUI
import SwiftData

/// 검색 — 해시태그·단어가 들어간 일기를 날짜별로 모아 보여준다.
struct SearchView: View {
    @Query private var allEntries: [Entry]
    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [Entry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let bare = q.hasPrefix("#") ? String(q.dropFirst()) : q
        return allEntries
            .filter { !$0.isEmpty }
            .filter {
                $0.text.lowercased().contains(bare) || $0.tagsRaw.lowercased().contains(bare)
            }
            .sorted { ($0.year, $0.date) > ($1.year, $1.date) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DiaryHeader()
                searchBar
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    hintView
                } else if results.isEmpty {
                    emptyView
                } else {
                    resultList
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

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.dgSub)
            TextField("해시태그나 단어로 검색", text: $query)
                .focused($focused).submitLabel(.search)
                .foregroundStyle(Color.dgInk)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.dgSub)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.dgCard))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.dgLine, lineWidth: 1))
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 12)
    }

    private var resultList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(results) { e in
                    NavigationLink(value: DayRoute(dateKey: e.date, year: e.year)) {
                        resultCard(e)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
    }

    private func resultCard(_ e: Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(String(e.year)).\(e.date.replacingOccurrences(of: "-", with: "."))")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.dgAccent)
                Spacer()
                if let m = e.mood { Text(m.emoji).font(.system(size: 15)) }
            }
            if !e.text.isEmpty {
                Text(e.text).font(.system(size: 15)).foregroundStyle(Color.dgOnDark)
                    .lineLimit(3).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !e.hashtags.isEmpty {
                Text(e.hashtags.joined(separator: " "))
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.dgAccentSoft)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.dgCardDark))
    }

    private var hintView: some View {
        VStack(spacing: 10) {
            Image(systemName: "number").font(.system(size: 40))
                .foregroundStyle(Color.dgFaint)
            Text("해시태그나 단어로 지난 일기를 찾아보세요")
                .font(.system(size: 14)).foregroundStyle(Color.dgSub)
            Text("예) #여행, 엄마, 도서관")
                .font(.system(size: 12)).foregroundStyle(Color.dgFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 80)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Text("🐻").font(.system(size: 40))
            Text("‘\(query)’ 가 들어간 일기가 없어요")
                .font(.system(size: 14)).foregroundStyle(Color.dgSub)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 80)
    }
}
