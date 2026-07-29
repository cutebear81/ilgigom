import SwiftUI
import SwiftData
import PhotosUI

/// 풀스크린 자유 에디터 — 텍스트 + 기분 + 사진 1장
struct EntryEditorView: View {
    let dateKey: String
    let year: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]

    @State private var text = ""
    @State private var mood: Mood?
    @State private var photo: Data?
    @State private var tags: [String] = []
    @State private var tagField = ""
    @State private var weatherNote: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var loaded = false
    @FocusState private var focused: Bool
    @StateObject private var weather = WeatherFetcher()

    init(dateKey: String, year: Int) {
        self.dateKey = dateKey
        self.year = year
        _entries = Query(filter: #Predicate<Entry> { $0.date == dateKey && $0.year == year })
    }

    private var existing: Entry? { entries.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 위치·날씨·시간 (기분 위)
                    weatherRow

                    // 기분 선택
                    VStack(alignment: .leading, spacing: 10) {
                        Text("오늘의 기분")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.dgSub)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Mood.allCases) { m in
                                    Button {
                                        withAnimation(.snappy) { mood = (mood == m ? nil : m) }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(m.emoji).font(.system(size: 26))
                                            Text(m.label).font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(mood == m ? .white : Color.dgSub)
                                        }
                                        .frame(width: 60, height: 66)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(mood == m ? m.tint : Color.dgCard)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Color.dgLine, lineWidth: mood == m ? 0 : 1)
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // 사진
                    if let data = photo, let ui = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Button { photo = nil; pickerItem = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24)).foregroundStyle(.white, .black.opacity(0.4))
                                    .padding(8)
                            }
                        }
                    } else {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                Text("사진 추가").font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(Color.dgSub)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.dgCard))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.dgLine, lineWidth: 1))
                        }
                    }

                    // 텍스트
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("오늘 하루를 자유롭게 적어보세요")
                                .font(.system(size: 16)).foregroundStyle(Color.dgFaint)
                                .padding(.top, 8).padding(.leading, 5)
                        }
                        TextEditor(text: $text)
                            .font(.system(size: 16)).foregroundStyle(Color.dgInk)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 200)
                            .focused($focused)
                    }

                    // 해시태그 입력창 (맨 밑) — 엔터로 칩 추가, 칩 우상단 x 삭제
                    VStack(alignment: .leading, spacing: 10) {
                        Text("해시태그").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.dgSub)
                        if !tags.isEmpty {
                            FlowLayout(spacing: 10) {
                                ForEach(tags, id: \.self) { tag in tagChip(tag) }
                            }
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "number").font(.system(size: 14)).foregroundStyle(Color.dgAccent)
                            TextField("태그 입력 후 엔터", text: $tagField)
                                .font(.system(size: 15)).foregroundStyle(Color.dgInk)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .onSubmit(addTag)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.dgCard))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.dgLine, lineWidth: 1))
                    }
                }
                .padding(20)
            }
            .background(Color.dgBackground.ignoresSafeArea())
            .navigationTitle("\(String(year))년 \(DiaryDate.korean(dateKey))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }.foregroundStyle(Color.dgInk)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.dgAccent)
                }
            }
            .onAppear(perform: loadOnce)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let d = try? await item.loadTransferable(type: Data.self) { photo = d }
                }
            }
        }
    }

    // 위치·날씨·시간 기록 줄
    private var weatherRow: some View {
        Button {
            weather.fetch { note in if let note { weatherNote = note } }
        } label: {
            HStack(spacing: 8) {
                if weather.loading {
                    ProgressView().controlSize(.small)
                    Text("위치·날씨 확인 중…").font(.system(size: 14)).foregroundStyle(Color.dgSub)
                } else if let note = weatherNote {
                    Image(systemName: "location.fill").font(.system(size: 12)).foregroundStyle(Color.dgAccent)
                    Text(note).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.dgInk)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.clockwise").font(.system(size: 12)).foregroundStyle(Color.dgSub)
                } else {
                    Image(systemName: "location").font(.system(size: 13)).foregroundStyle(Color.dgAccent)
                    Text("위치·날씨·시간 기록").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.dgInk)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.dgCard))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.dgLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // 해시태그 칩
    private func tagChip(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.dgAccent)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.dgAccent.opacity(0.12)))
            .overlay(alignment: .topTrailing) {
                Button {
                    tags.removeAll { $0 == tag }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white, Color.dgSub)
                }
                .offset(x: 6, y: -6)
            }
            .padding(.top, 6).padding(.trailing, 6)
    }

    private func addTag() {
        var t = tagField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if !t.hasPrefix("#") { t = "#" + t }
        if !tags.contains(t) { tags.append(t) }
        tagField = ""
    }

    private func loadOnce() {
        guard !loaded else { return }
        loaded = true
        if let e = existing {
            text = e.text; mood = e.mood; photo = e.photo
            tags = e.hashtags; weatherNote = e.weatherNote
        }
        if (existing?.isEmpty ?? true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    private func save() {
        // 입력 중이던 태그도 저장에 반영
        addTag()
        let tagsJoined = tags.joined(separator: " ")
        if let e = existing {
            e.text = text; e.mood = mood; e.photo = photo
            e.tagsRaw = tagsJoined; e.weatherNote = weatherNote; e.updatedAt = Date()
        } else {
            let e = Entry(date: dateKey, year: year, text: text, mood: mood, photo: photo,
                          tagsRaw: tagsJoined, weatherNote: weatherNote)
            context.insert(e)
        }
        try? context.save()
        dismiss()
    }
}

/// 칩을 줄바꿈 배치하는 간단 Flow 레이아웃
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}
