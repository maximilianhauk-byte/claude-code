import Foundation

/// Berechnet Sonnenaufgangszeiten aus Breiten-/Längengrad und Datum.
///
/// Implementiert den öffentlich dokumentierten NOAA-Sonnenstand-Algorithmus
/// (astronomische Standardformeln, siehe NOAA Solar Calculator / "Sunrise
/// equation"). Arbeitet komplett offline, ohne externe API.
enum SunCalculator {

    /// Liefert den nächsten Sonnenaufgang (in der Zukunft) für die gegebene
    /// Position, ausgehend von `referenceDate`.
    static func nextSunrise(latitude: Double, longitude: Double, after referenceDate: Date = Date()) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        for dayOffset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate) else { continue }
            if let sunrise = sunrise(on: day, latitude: latitude, longitude: longitude), sunrise > referenceDate {
                return sunrise
            }
        }
        return nil
    }

    /// Sonnenaufgang für ein bestimmtes Kalenderdatum (lokaler Tag, UTC-Berechnung).
    static func sunrise(on date: Date, latitude: Double, longitude: Double) -> Date? {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return nil }

        let jd = julianDay(year: year, month: month, day: day)
        let t = (jd - 2451545.0) / 36525.0

        let l0 = normalizedDegrees(280.46646 + t * (36000.76983 + t * 0.0003032))
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let mRad = radians(m)
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3 * mRad) * 0.000289

        let trueLongitude = l0 + c
        let omega = 125.04 - 1934.136 * t
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(radians(omega))

        let epsilon0 = 23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        let epsilon = epsilon0 + 0.00256 * cos(radians(omega))

        let declination = asin(sin(radians(epsilon)) * sin(radians(apparentLongitude)))

        let y = pow(tan(radians(epsilon / 2.0)), 2)
        let eqTime = 4.0 * degrees(
            y * sin(2 * radians(l0))
            - 2 * e * sin(mRad)
            + 4 * e * y * sin(mRad) * cos(2 * radians(l0))
            - 0.5 * y * y * sin(4 * radians(l0))
            - 1.25 * e * e * sin(2 * mRad)
        )

        // 90.833° berücksichtigt atmosphärische Refraktion und den Sonnenradius.
        let latRad = radians(latitude)
        let cosHA = (cos(radians(90.833)) / (cos(latRad) * cos(declination))) - tan(latRad) * tan(declination)
        guard cosHA >= -1, cosHA <= 1 else {
            // Polartag/-nacht: kein Sonnenaufgang an diesem Tag.
            return nil
        }
        let ha = degrees(acos(cosHA))

        let solarNoonMinutes = 720.0 - 4.0 * longitude - eqTime
        let sunriseMinutesUTC = solarNoonMinutes - 4.0 * ha

        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        guard let midnightUTC = utcCalendar.date(from: dateComponents) else { return nil }

        return midnightUTC.addingTimeInterval(sunriseMinutesUTC * 60.0)
    }

    // MARK: - Helpers

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(Double(y) / 100.0)
        let b = 2 - a + floor(a / 4.0)
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + b - 1524.5
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180.0 }
    private static func degrees(_ radians: Double) -> Double { radians * 180.0 / .pi }
    private static func normalizedDegrees(_ degrees: Double) -> Double {
        let d = degrees.truncatingRemainder(dividingBy: 360.0)
        return d < 0 ? d + 360.0 : d
    }
}
