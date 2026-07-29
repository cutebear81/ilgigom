import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

// 내보내기용 DTO
private struct EntryDTO: Codable {
    var date: String; var year: Int; var text: String; var mood: String?; var createdAt: Date
}

struct SettingsView: View {
    @Query private var allEntries: [Entry]
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context

    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("lockMethod") private var lockMethod = "bio"
    @AppStorage("lockPIN") private var lockPIN = ""
    @State private var showLockMethod = false
    @State private var showPinSetup = false

    @State private var showExport = false
    @State private var showTipJar = false
    @State private var showImport = false
    @State private var importResult: String?

    private var filledCount: Int { allEntries.filter { !$0.isEmpty }.count }

    /// AppStorage(hour/minute) ↔ DatePicker(Date) 브리지
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = reminderHour; c.minute = reminderMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = c.hour ?? 21
                reminderMinute = c.minute ?? 0
                if reminderEnabled { ReminderManager.schedule(hour: reminderHour, minute: reminderMinute) }
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DiaryHeader()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        summaryCard

                        // 알림 · 잠금
                        settingsGroup {
                            toggleRow(icon: "bell", title: "매일 알림", isOn: Binding(
                                get: { reminderEnabled },
                                set: { on in
                                    reminderEnabled = on
                                    if on { ReminderManager.enable(hour: reminderHour, minute: reminderMinute) }
                                    else { ReminderManager.cancel() }
                                }
                            ))
                            if reminderEnabled {
                                divider
                                HStack(spacing: 14) {
                                    Image(systemName: "clock").font(.system(size: 16)).foregroundStyle(Color.dgAccent).frame(width: 22)
                                    Text("알림 시간").font(.system(size: 15, weight: .medium)).foregroundStyle(Color.dgInk)
                                    Spacer()
                                    DatePicker("", selection: reminderTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden().tint(Color.dgAccent)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            }
                            divider
                            toggleRow(icon: "lock", title: "앱 잠금", isOn: Binding(
                                get: { lockEnabled },
                                set: { on in
                                    if on { showLockMethod = true }
                                    else { lockEnabled = false; lockPIN = ""; lockMethod = "bio" }
                                }
                            ))
                            if lockEnabled {
                                divider
                                Button { showLockMethod = true } label: {
                                    linkRow(icon: "key", title: "잠금 방식",
                                            trailing: lockMethod == "pin" ? "비밀번호" : "Face ID")
                                }
                            }
                        }

                        // 백업 · 가져오기
                        settingsGroup {
                            Button { showExport = true } label: {
                                linkRow(icon: "icloud.and.arrow.up", title: "iCloud로 내보내기 · 백업")
                            }
                            divider
                            Button { showImport = true } label: {
                                linkRow(icon: "square.and.arrow.down", title: "파일에서 가져오기 (CSV · JSON)")
                            }
                        }

                        // 지원
                        settingsGroup {
                            Button { showTipJar = true } label: {
                                linkRow(icon: "heart", title: "후원하기")
                            }
                            divider
                            Button {
                                openURL(URL(string: "mailto:tonyneplanning@gmail.com?subject=일기곰%20문의")!)
                            } label: {
                                linkRow(icon: "envelope", title: "문의하기")
                            }
                            divider
                            linkRow(icon: "info.circle", title: "버전", trailing: "0.1.0")
                        }

                        Text("일기곰 · 하루 한 줄, 10년의 오늘")
                            .font(.system(size: 11)).foregroundStyle(Color.dgFaint).padding(.top, 8)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 30)
                }
            }
            .background(Color.dgBackground.ignoresSafeArea())
            .sheet(isPresented: $showExport) {
                if let url = exportFileURL() {
                    ActivityView(items: [url])
                } else {
                    Text("내보낼 기록이 없어요").padding()
                }
            }
            .sheet(isPresented: $showTipJar) { TipJarView() }
            .confirmationDialog("잠금 방식 선택", isPresented: $showLockMethod, titleVisibility: .visible) {
                Button("Face ID / Touch ID") { lockMethod = "bio"; lockEnabled = true }
                Button("비밀번호(PIN)") { showPinSetup = true }
                Button("취소", role: .cancel) {}
            }
            .sheet(isPresented: $showPinSetup) {
                PinSetupView { newPin in
                    lockPIN = newPin; lockMethod = "pin"; lockEnabled = true
                }
            }
            .fileImporter(isPresented: $showImport,
                          allowedContentTypes: [.commaSeparatedText, .json, .text, .plainText],
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .alert("가져오기", isPresented: Binding(get: { importResult != nil },
                                                 set: { if !$0 { importResult = nil } })) {
                Button("확인", role: .cancel) { importResult = nil }
            } message: {
                Text(importResult ?? "")
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 6) {
            Text("지금까지 \(filledCount)일 기록했어요")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(Color.dgInk)
            Text("하루 한 줄, 10년의 오늘")
                .font(.system(size: 12)).foregroundStyle(Color.dgSub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.dgCard))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.dgLine, lineWidth: 1))
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let needStop = url.startAccessingSecurityScopedResource()
        defer { if needStop { url.stopAccessingSecurityScopedResource() } }
        let rows = DiaryImporter.parse(url: url)
        guard !rows.isEmpty else { importResult = "가져올 수 있는 일기를 찾지 못했어요. 파일 형식을 확인해주세요."; return }
        let n = DiaryImporter.importRows(rows, into: context, existing: allEntries)
        importResult = "\(n)개의 일기를 가져왔어요."
    }

    private func exportFileURL() -> URL? {
        let dtos = allEntries.filter { !$0.isEmpty }
            .map { EntryDTO(date: $0.date, year: $0.year, text: $0.text, mood: $0.moodRaw, createdAt: $0.createdAt) }
        guard !dtos.isEmpty else { return nil }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(dtos) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ilgigom_backup.json")
        try? data.write(to: url)
        return url
    }

    private func settingsGroup<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.dgCard))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.dgLine, lineWidth: 1))
    }
    private var divider: some View { Rectangle().fill(Color.dgLine).frame(height: 1).padding(.leading, 50) }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Color.dgAccent).frame(width: 22)
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.dgInk)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Color.dgAccent)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
    private func linkRow(icon: String, title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Color.dgAccent).frame(width: 22)
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.dgInk)
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 13)).foregroundStyle(Color.dgSub) }
            else { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.dgFaint) }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// 공유 시트 (iCloud Drive 저장 가능)
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
