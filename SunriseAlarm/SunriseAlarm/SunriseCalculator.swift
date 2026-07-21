import Foundation

/// Offline sunrise/sunset calculation (no network required).
/// Implements the standard solar position algorithm from the
/// "Almanac for Computers" (US Naval Observatory, 1990), accurate to
/// roughly ±1–2 minutes almost everywhere on Earth.
enum SunriseCalculator {

    static func sunrise(for date: Date, latitude: Double, longitude: Double) -> Date? {
        sun(for: date, latitude: latitude, longitude: longitude, rising: true)
    }

    static func sunset(for date: Date, latitude: Double, longitude: Double) -> Date? {
        sun(for: date, latitude: latitude, longitude: longitude, rising: false)
    }

    private static func sun(for date: Date, latitude: Double, longitude: Double, rising: Bool) -> Date? {
        let zenith = 90.833 // official sunrise/sunset zenith (includes refraction + solar disk radius)
        let deg2rad = Double.pi / 180
        let rad2deg = 180 / Double.pi

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        guard let dayOfYear = utcCalendar.ordinality(of: .day, in: .year, for: date) else { return nil }
        let n = Double(dayOfYear)

        let lngHour = longitude / 15.0
        let t = rising ? n + ((6 - lngHour) / 24) : n + ((18 - lngHour) / 24)

        let m = (0.9856 * t) - 3.289

        var l = m + (1.916 * sin(m * deg2rad)) + (0.020 * sin(2 * m * deg2rad)) + 282.634
        l = l.truncatingRemainder(dividingBy: 360)
        if l < 0 { l += 360 }

        var ra = rad2deg * atan(0.91764 * tan(l * deg2rad))
        ra = ra.truncatingRemainder(dividingBy: 360)
        if ra < 0 { ra += 360 }

        let lQuadrant = floor(l / 90) * 90
        let raQuadrant = floor(ra / 90) * 90
        ra += (lQuadrant - raQuadrant)
        ra /= 15

        let sinDec = 0.39782 * sin(l * deg2rad)
        let cosDec = cos(asin(sinDec))

        let cosH = (cos(zenith * deg2rad) - (sinDec * sin(latitude * deg2rad))) / (cosDec * cos(latitude * deg2rad))

        if cosH > 1 { return nil }  // sun never rises at this location/date (polar night)
        if cosH < -1 { return nil } // sun never sets (polar day)

        var h = rising ? 360 - rad2deg * acos(cosH) : rad2deg * acos(cosH)
        h /= 15

        let tLocal = h + ra - (0.06571 * t) - 6.622

        var utHours = tLocal - lngHour
        utHours = utHours.truncatingRemainder(dividingBy: 24)
        if utHours < 0 { utHours += 24 }

        var comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
        let hour = Int(utHours)
        let minuteFraction = (utHours - Double(hour)) * 60
        let minute = Int(minuteFraction)
        let second = Int((minuteFraction - Double(minute)) * 60)
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return utcCalendar.date(from: comps)
    }
}
