import Foundation
import CoreLocation

/// 현재 위치 + 날씨 + 시간을 "서울 · 맑음 22° · 오후 3:20" 형태로 만들어 준다.
/// 날씨는 무료 open-meteo API (키 불필요).
@MainActor
final class WeatherFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var loading = false
    private let manager = CLLocationManager()
    private var completion: ((String?) -> Void)?

    func fetch(_ done: @escaping (String?) -> Void) {
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
        let weather = await currentWeather(loc.coordinate)
        let time = timeString()
        var parts: [String] = []
        if let city { parts.append(city) }
        if let weather { parts.append(weather) }
        parts.append(time)
        finish(parts.joined(separator: " · "))
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
