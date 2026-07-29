import Foundation
import SwiftData

/// CSV / JSON 파일에서 일기를 읽어 날짜별로 등록한다.
enum DiaryImporter {

    struct Row {
        var dateKey: String   // "MM-DD"
        var year: Int
        var text: String
        var mood: Mood?
        var tags: String
    }

    /// 확장자·내용으로 파싱해 Row 배열 반환
    static func parse(url: URL) -> [Row] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let ext = url.pathExtension.lowercased()
        if ext == "json" { return parseJSON(data) }
        if let text = String(data: data, encoding: .utf8) { return parseCSV(text) }
        return []
    }

    // MARK: JSON (내보내기 호환: date "MM-DD" + year, 또는 "YYYY-MM-DD")
    private struct DTO: Codable { var date: String; var year: Int?; var text: String?; var mood: String?; var tags: String? }
    private static func parseJSON(_ data: Data) -> [Row] {
        guard let dtos = try? JSONDecoder().decode([DTO].self, from: data) else { return [] }
        return dtos.compactMap { dto in
            let (key, yr) = splitDate(dto.date, fallbackYear: dto.year)
            guard let key, let yr else { return nil }
            return Row(dateKey: key, year: yr, text: dto.text ?? "",
                       mood: dto.mood.flatMap(Mood.from), tags: dto.tags ?? "")
        }
    }

    // MARK: CSV (헤더: date,text,mood,tags / date = YYYY-MM-DD)
    private static func parseCSV(_ text: String) -> [Row] {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty else { return [] }

        // 헤더 매핑
        let header = splitCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let hasHeader = header.contains("date")
        var idx: [String: Int] = [:]
        if hasHeader {
            for (i, h) in header.enumerated() { idx[h] = i }
            lines.removeFirst()
        } else {
            idx = ["date": 0, "text": 1, "mood": 2, "tags": 3]
        }

        return lines.compactMap { line in
            let cols = splitCSVLine(line)
            func col(_ name: String) -> String {
                guard let i = idx[name], i < cols.count else { return "" }
                return cols[i].trimmingCharacters(in: .whitespaces)
            }
            let (key, yr) = splitDate(col("date"), fallbackYear: nil)
            guard let key, let yr else { return nil }
            return Row(dateKey: key, year: yr, text: col("text"),
                       mood: Mood.from(col("mood")), tags: col("tags"))
        }
    }

    /// "YYYY-MM-DD" → (MM-DD, YYYY) / "MM-DD"(+fallbackYear) → (MM-DD, fallbackYear)
    private static func splitDate(_ s: String, fallbackYear: Int?) -> (String?, Int?) {
        let parts = s.trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0 == "-" || $0 == "." || $0 == "/" }).map(String.init)
        if parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
            return (String(format: "%02d-%02d", m, d), y)
        }
        if parts.count == 2, let m = Int(parts[0]), let d = Int(parts[1]) {
            return (String(format: "%02d-%02d", m, d), fallbackYear)
        }
        return (nil, nil)
    }

    /// 따옴표(") 감싼 필드 지원 CSV 한 줄 분해
    private static func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []; var cur = ""; var inQuotes = false
        var chars = Array(line); var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i+1] == "\"" { cur.append("\""); i += 1 }
                else { inQuotes.toggle() }
            } else if c == "," && !inQuotes {
                result.append(cur); cur = ""
            } else { cur.append(c) }
            i += 1
        }
        result.append(cur)
        return result
    }

    /// 실제 등록. 반환 = 가져온 개수. 같은 (date,year)는 덮어쓰기.
    @discardableResult
    static func importRows(_ rows: [Row], into context: ModelContext, existing: [Entry]) -> Int {
        var byKey: [String: Entry] = [:]
        for e in existing { byKey["\(e.date)-\(e.year)"] = e }
        var count = 0
        for r in rows where !(r.text.isEmpty && r.mood == nil && r.tags.isEmpty) {
            let k = "\(r.dateKey)-\(r.year)"
            if let e = byKey[k] {
                e.text = r.text; e.mood = r.mood; e.tagsRaw = r.tags; e.updatedAt = Date()
            } else {
                let e = Entry(date: r.dateKey, year: r.year, text: r.text, mood: r.mood, tagsRaw: r.tags)
                context.insert(e); byKey[k] = e
            }
            count += 1
        }
        try? context.save()
        return count
    }
}
