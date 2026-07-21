import Foundation

/// Computes sunrise/sunset times from a location and calendar day.
///
/// Uses the NOAA "sunrise equation" approximation (see
/// https://en.wikipedia.org/wiki/Sunrise_equation). Accurate to roughly a
/// minute, which is more than enough for waking someone up.
enum SunCalculator {

    static func sunrise(on date: Date, latitude: Double, longitude: Double) -> Date? {
        sunEvent(on: date, latitude: latitude, longitude: longitude, isSunrise: true)
    }

    static func sunset(on date: Date, latitude: Double, longitude: Double) -> Date? {
        sunEvent(on: date, latitude: latitude, longitude: longitude, isSunrise: false)
    }

    private static func sunEvent(on date: Date, latitude: Double, longitude: Double, isSunrise: Bool) -> Date? {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // Anchor the calculation to local noon UTC of the given calendar date.
        guard let noon = utcCalendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) else {
            return nil
        }
        let julianDate = julianDay(from: noon)

        let n = julianDate - 2451545.0 + 0.0008
        let jStar = n - longitude / 360.0

        let meanAnomalyDeg = normalizedDegrees(357.5291 + 0.98560028 * jStar)
        let M = meanAnomalyDeg * .pi / 180

        let equationOfCenter = 1.9148 * sin(M) + 0.0200 * sin(2 * M) + 0.0003 * sin(3 * M)

        let eclipticLongitudeDeg = normalizedDegrees(meanAnomalyDeg + 102.9372 + equationOfCenter + 180)
        let lambda = eclipticLongitudeDeg * .pi / 180

        let jTransit = 2451545.0 + jStar + 0.0053 * sin(M) - 0.0069 * sin(2 * lambda)

        let earthAxialTilt = 23.4397 * Double.pi / 180
        let declination = asin(sin(lambda) * sin(earthAxialTilt))

        let latRad = latitude * .pi / 180
        let cosOmega = (sin(-0.833 * .pi / 180) - sin(latRad) * sin(declination))
            / (cos(latRad) * cos(declination))

        // cosOmega outside [-1, 1] means the sun doesn't rise/set that day
        // (polar day or polar night).
        guard cosOmega >= -1, cosOmega <= 1 else { return nil }

        let omegaDeg = acos(cosOmega) * 180 / .pi
        let jEvent = isSunrise ? jTransit - omegaDeg / 360 : jTransit + omegaDeg / 360

        return dateFromJulianDay(jEvent)
    }

    private static func normalizedDegrees(_ degrees: Double) -> Double {
        let result = degrees.truncatingRemainder(dividingBy: 360)
        return result < 0 ? result + 360 : result
    }

    private static func julianDay(from date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    private static func dateFromJulianDay(_ jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2440587.5) * 86400.0)
    }
}
