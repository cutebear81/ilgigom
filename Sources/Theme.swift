import SwiftUI

// 토니네 공통 톤: 오프화이트 #F7F4EF / 블랙 #1A1A1A / 오렌지 #EE6B26
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }

    static let dgBackground = Color(hex: "F7F4EF")   // 오프화이트 페이지
    static let dgCard       = Color(hex: "FFFFFF")   // 밝은 카드
    static let dgInk        = Color(hex: "1A1A1A")   // 본문 블랙
    static let dgSub        = Color(hex: "8A857C")   // 보조 텍스트
    static let dgFaint      = Color(hex: "CFC9BE")   // 빈 해/점선
    static let dgAccent     = Color(hex: "EE6B26")   // 오렌지 포인트
    static let dgAccentSoft = Color(hex: "F6C9A8")   // 연한 오렌지
    static let dgLine       = Color(hex: "E7E2D8")   // 구분선

    // 다크 카드 (일기 카드)
    static let dgCardDark    = Color(hex: "1A1817")   // 다크 카드 배경
    static let dgOnDark      = Color(hex: "ECEAE4")   // 다크 카드 위 본문
    static let dgOnDarkSub   = Color(hex: "9A968E")   // 다크 카드 위 보조
    static let dgEmptyCard   = Color(hex: "EFEBE3")   // 빈/사진 카드(연한)
}

enum DiaryConfig {
    static let span = 10   // 올해 포함 최근 10년 (10년 전 오늘 ~ 오늘)
    static var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    /// 오름차순 [올해-9 ... 올해]
    static var years: [Int] { Array((currentYear - span + 1) ... currentYear) }
    /// 표시용 내림차순 [올해 ... 올해-9] (오늘이 맨 위)
    static var yearsDescending: [Int] { years.reversed() }
}
