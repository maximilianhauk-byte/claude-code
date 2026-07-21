import Foundation

/// Computes sunrise times from a date and geographic coordinate.
///
/// Port of the well-known "sunrise equation" (as used by the SunCalc.js
/// library), accurate to roughly a minute for non-polar latitudes. Runs
/// fully offline - no network request or API key needed.
enum SunCalculator {

    private static let dayMs = 86_400.0
    private static let j1970 = 2_440_588.0
    private static let j2000 = 2_451_545.0
    private static let rad = Double.pi / 180
    private static let obliquity = (23.4397) * (Double.pi / 180)

    private static func toJulian(_ date: Date) -> Double {
        date.timeIntervalSince1970 / dayMs - 0.5 + j1970
    }

    private static func fromJulian(_ j: Double) -> Date {
        Date(timeIntervalSince1970: (j - j1970 + 0.5) * dayMs)
    }

    private static func toDays(_ date: Date) -> Double {
        toJulian(date) - j2000
    }

    private static func declination(l: Double) -> Double {
        asin(sin(l) * cos(obliquity))
    }

    private static func solarMeanAnomaly(_ d: Double) -> Double {
        rad * (357.5291 + 0.98560028 * d)
    }

    private static func eclipticLongitude(_ m: Double) -> Double {
        let c = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        let p = rad * 102.9372
        return m + c + p + Double.pi
    }

    private static func julianCycle(d: Double, lw: Double) -> Double {
        (d - 0.0009 - lw / (2 * Double.pi)).rounded()
    }

    private static func approxTransit(ht: Double, lw: Double, n: Double) -> Double {
        0.0009 + (ht + lw) / (2 * Double.pi) + n
    }

    private static func solarTransitJ(ds: Double, m: Double, l: Double) -> Double {
        j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l)
    }

    /// Returns nil for polar day/night, where the given event angle is never crossed.
    private static func hourAngle(h: Double, phi: Double, d: Double) -> Double? {
        let cosw = (sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d))
        guard cosw >= -1, cosw <= 1 else { return nil }
        return acos(cosw)
    }

    /// The sunrise for the given calendar day at the given coordinate, in the device's
    /// local calendar day (the `date` argument may be any time on that day).
    /// Returns nil during polar day/night when there is no sunrise that day.
    static func sunrise(on date: Date, latitude: Double, longitude: Double) -> Date? {
        let lw = rad * (-longitude)
        let phi = rad * latitude
        let d = toDays(date)
        let n = julianCycle(d: d, lw: lw)
        let ds = approxTransit(ht: 0, lw: lw, n: n)
        let m = solarMeanAnomaly(ds)
        let l = eclipticLongitude(m)
        let dec = declination(l: l)
        let jNoon = solarTransitJ(ds: ds, m: m, l: l)

        // -0.833 degrees accounts for atmospheric refraction and the sun's radius.
        let h0 = rad * -0.833
        guard let w = hourAngle(h: h0, phi: phi, d: dec) else { return nil }
        let a = approxTransit(ht: w, lw: lw, n: n)
        let jSet = solarTransitJ(ds: a, m: m, l: l)
        let jRise = jNoon - (jSet - jNoon)
        return fromJulian(jRise)
    }

    /// The next sunrise strictly after `after`, searching forward day by day.
    static func nextSunrise(after: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> Date? {
        var day = after
        for _ in 0..<400 {
            if let sunrise = sunrise(on: day, latitude: latitude, longitude: longitude), sunrise > after {
                return sunrise
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
        }
        return nil
    }
}
