import Foundation
import CoreLocation

/// 현재 위치 + 날씨를 문자열로 만들어 준다. 무료 open-meteo API (키 불필요).
/// - 오늘   : 실시간 날씨 + 시각        "서울 · 맑음 22° · 오후 3:20"
/// - 과거   : 그날의 일 평균기온 + 날씨  "서울 · 맑음 평균 26°"
/// - 미래   : 날씨 없음 → nil (에디터에서 안내)
@MainActor
final class WeatherFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var loading = false
    private let manager = CLLocationManager()
    private var completion: ((String?) -> Void)?
    /// 이번 조회가 대상으로 하는 날짜(자정 기준). nil = 오늘.
    private var targetDate: Date?

    /// - Parameter date: 일기 날짜. 오늘이면 실시간, 과거면 평균기온을 기록한다.
    func fetch(for date: Date? = nil, _ done: @escaping (String?) -> Void) {
        targetDate = date
        completion = done
        loading = true
        manager.delegate = self
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            finish(nil)
        } else {
            manager.requestLocation()
        }
    }

    // 권한 응답
    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        switch m.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: m.requestLocation()
        case .denied, .restricted: finish(nil)
        default: break
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.first else { finish(nil); return }
        Task { await build(from: loc) }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }

    private func build(from loc: CLLocation) async {
        let city = await reverseCity(loc)
        // 과거 날짜면 그날의 평균기온, 아니면 현재 실황
        let cal = Calendar.current
        let isPast = targetDate.map { cal.startOfDay(for: $0) < cal.startOfDay(for: Date()) } ?? false
        var parts: [String] = []
        if let city { parts.append(city) }
        if isPast, let date = targetDate {
            if let weather = await pastWeather(loc.coordinate, date: date) {
                parts.append(weather)
            }
        } else {
            if let weather = await currentWeather(loc.coordinate) { parts.append(weather) }
            parts.append(timeString())
        }
        finish(parts.count > 1 ? parts.joined(separator: " · ") : nil)
    }

    private func reverseCity(_ loc: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        let placemarks = try? await geocoder.reverseGeocodeLocation(loc,
            preferredLocale: Locale(identifier: "ko_KR"))
        guard let p = placemarks?.first else { return nil }
        return p.locality ?? p.subAdministrativeArea ?? p.administrativeArea
    }

    private func currentWeather(_ coord: CLLocationCoordinate2D) async -> String? {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&current=temperature_2m,weather_code&timezone=auto"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any] else { return nil }
        let temp = (current["temperature_2m"] as? Double).map { Int($0.rounded()) }
        let code = current["weather_code"] as? Int
        let desc = code.map(Self.weatherText) ?? ""
        if let temp { return desc.isEmpty ? "\(temp)°" : "\(desc) \(temp)°" }
        return desc.isEmpty ? nil : desc
    }

    /// 과거 특정 날짜의 일 평균기온 + 그날 날씨 (open-meteo archive, 키 불필요)
    private func pastWeather(_ coord: CLLocationCoordinate2D, date: Date) async -> String? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let day = f.string(from: date)
        let urlStr = "https://archive-api.open-meteo.com/v1/archive?latitude=\(coord.latitude)&longitude=\(coord.longitude)&start_date=\(day)&end_date=\(day)&daily=temperature_2m_mean,weather_code&timezone=auto"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daily = json["daily"] as? [String: Any] else {
            // 아카이브 실패(최근 5일 등) → 현재 실황으로 대체
            return await currentWeather(coord)
        }
        let temp = (daily["temperature_2m_mean"] as? [Any])?.first
            .flatMap { $0 as? Double }.map { Int($0.rounded()) }
        let code = (daily["weather_code"] as? [Any])?.first.flatMap { $0 as? Int }
        // 최근 날짜라 아직 기록이 없으면(null) 실황으로 대체
        guard let temp else { return await currentWeather(coord) }
        let desc = code.map(Self.weatherText) ?? ""
        return desc.isEmpty ? "평균 \(temp)°" : "\(desc) 평균 \(temp)°"
    }

    private func timeString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: Date())
    }

    private func finish(_ result: String?) {
        loading = false
        completion?(result)
        completion = nil
    }

    /// WMO weather code → 한국어
    static func weatherText(_ code: Int) -> String {
        switch code {
        case 0: return "맑음"
        case 1, 2: return "대체로 맑음"
        case 3: return "흐림"
        case 45, 48: return "안개"
        case 51, 53, 55, 56, 57: return "이슬비"
        case 61, 63, 65, 66, 67: return "비"
        case 71, 73, 75, 77: return "눈"
        case 80, 81, 82: return "소나기"
        case 85, 86: return "눈"
        case 95, 96, 99: return "뇌우"
        default: return ""
        }
    }
}
