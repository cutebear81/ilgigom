import SwiftUI
import SwiftData

// 기분 — 곰 표정 1:1 (성장/코멘트 없음, 순수 미러링)
enum Mood: String, CaseIterable, Codable, Identifiable {
    case happy, love, soso, tired, sad, angry
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .love:  return "🥰"
        case .soso:  return "😐"
        case .tired: return "😴"
        case .sad:   return "😢"
        case .angry: return "😠"
        }
    }
    var label: String {
        switch self {
        case .happy: return "좋아요"
        case .love:  return "설레요"
        case .soso:  return "그냥"
        case .tired: return "지쳐요"
        case .sad:   return "슬퍼요"
        case .angry: return "화나요"
        }
    }
    var tint: Color {
        switch self {
        case .happy: return Color(hex: "F2A93B")
        case .love:  return Color(hex: "E86B8A")
        case .soso:  return Color(hex: "9AA0A6")
        case .tired: return Color(hex: "8E7CC3")
        case .sad:   return Color(hex: "5B8DEF")
        case .angry: return Color(hex: "E4572E")
        }
    }
}

// 일기 엔트리 — 고유 키 (date, year) 1쌍 = 1엔트리
@Model
final class Entry {
    var date: String   // "MM-DD"
    var year: Int      // 2026~2035
    var text: String
    var moodRaw: String?
    var photo: Data?
    var tagsRaw: String = ""       // 해시태그 (공백 구분, # 포함)
    var weatherNote: String?       // "서울 · 맑음 22° · 오후 3:20"
    var createdAt: Date
    var updatedAt: Date

    init(date: String, year: Int, text: String = "", mood: Mood? = nil, photo: Data? = nil,
         tagsRaw: String = "", weatherNote: String? = nil) {
        self.date = date
        self.year = year
        self.text = text
        self.moodRaw = mood?.rawValue
        self.photo = photo
        self.tagsRaw = tagsRaw
        self.weatherNote = weatherNote
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var mood: Mood? {
        get { moodRaw.flatMap(Mood.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }
    /// 해시태그 배열 (# 붙은 토큰)
    var hashtags: [String] {
        tagsRaw.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" })
            .map { String($0) }
            .map { $0.hasPrefix("#") ? $0 : "#" + $0 }
            .filter { $0.count > 1 }
    }
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photo == nil && tagsRaw.isEmpty
    }
}

// 날짜 유틸
enum DiaryDate {
    static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return String(format: "%02d-%02d", c.month ?? 1, c.day ?? 1)
    }
    static func year(_ date: Date) -> Int { Calendar.current.component(.year, from: date) }

    /// "MM-DD" → "M월 D일"
    static func korean(_ key: String) -> String {
        let p = key.split(separator: "-")
        guard p.count == 2, let m = Int(p[0]), let d = Int(p[1]) else { return key }
        return "\(m)월 \(d)일"
    }
    /// 특정 연·MM-DD의 요일 ("월"~"일"), 유효하지 않으면 nil
    static func weekday(year: Int, key: String) -> String? {
        let p = key.split(separator: "-")
        guard p.count == 2, let m = Int(p[0]), let d = Int(p[1]) else { return nil }
        var comp = DateComponents(); comp.year = year; comp.month = m; comp.day = d
        guard let date = Calendar.current.date(from: comp) else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}
