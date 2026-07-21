import Foundation

/// Computes sunrise times from latitude/longitude/date using the NOAA solar
/// position algorithm (the same formulas behind NOAA's public solar
/// calculator). Accurate to within about a minute, no network required.
enum SunCalculator {

    /// Returns the UTC instant of sunrise for the given calendar day (taken
    /// from `date` in the device's current calendar) at the given
    /// coordinates. Returns `nil` for locations/dates with no sunrise
    /// (polar day/night).
    static func sunrise(on date: Date, latitude: Double, longitude: Double) -> Date? {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard var year = comps.year, var month = comps.month, let day = comps.day else { return nil }

        if month <= 2 {
            year -= 1
            month += 12
        }
        let a = floor(Double(year) / 100.0)
        let b = 2 - a + floor(a / 4.0)
        let jd = floor(365.25 * (Double(year) + 4716.0))
            + floor(30.6001 * (Double(month) + 1.0))
            + Double(day) + b - 1524.5

        guard let timeUTCMinutes = sunriseUTCMinutes(jd: jd, latitude: latitude, longitude: longitude) else {
            return nil
        }

        let finalJD = jd + timeUTCMinutes / 1440.0
        let unixEpochJD = 2440587.5
        let seconds = (finalJD - unixEpochJD) * 86400.0
        return Date(timeIntervalSince1970: seconds)
    }

    // MARK: - NOAA solar position formulas

    private static func degToRad(_ deg: Double) -> Double { deg * .pi / 180.0 }
    private static func radToDeg(_ rad: Double) -> Double { rad * 180.0 / .pi }

    private static func julianCentury(jd: Double) -> Double { (jd - 2451545.0) / 36525.0 }
    private static func jdFromJulianCentury(_ t: Double) -> Double { t * 36525.0 + 2451545.0 }

    private static func geomMeanLongSun(_ t: Double) -> Double {
        var l0 = 280.46646 + t * (36000.76983 + t * 0.0003032)
        l0 = l0.truncatingRemainder(dividingBy: 360)
        return l0 < 0 ? l0 + 360 : l0
    }

    private static func geomMeanAnomalySun(_ t: Double) -> Double {
        357.52911 + t * (35999.05029 - 0.0001537 * t)
    }

    private static func eccentricityEarthOrbit(_ t: Double) -> Double {
        0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    }

    private static func sunEqOfCenter(_ t: Double) -> Double {
        let m = geomMeanAnomalySun(t)
        let mrad = degToRad(m)
        let sinm = sin(mrad), sin2m = sin(2 * mrad), sin3m = sin(3 * mrad)
        return sinm * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin2m * (0.019993 - 0.000101 * t)
            + sin3m * 0.000289
    }

    private static func sunTrueLong(_ t: Double) -> Double {
        geomMeanLongSun(t) + sunEqOfCenter(t)
    }

    private static func sunApparentLong(_ t: Double) -> Double {
        let o = sunTrueLong(t)
        let omega = 125.04 - 1934.136 * t
        return o - 0.00569 - 0.00478 * sin(degToRad(omega))
    }

    private static func meanObliquityOfEcliptic(_ t: Double) -> Double {
        let seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))
        return 23.0 + (26.0 + seconds / 60.0) / 60.0
    }

    private static func obliquityCorrection(_ t: Double) -> Double {
        let e0 = meanObliquityOfEcliptic(t)
        let omega = 125.04 - 1934.136 * t
        return e0 + 0.00256 * cos(degToRad(omega))
    }

    private static func sunDeclination(_ t: Double) -> Double {
        let e = obliquityCorrection(t)
        let lambda = sunApparentLong(t)
        let sint = sin(degToRad(e)) * sin(degToRad(lambda))
        return radToDeg(asin(sint))
    }

    private static func equationOfTime(_ t: Double) -> Double {
        let epsilon = obliquityCorrection(t)
        let l0 = geomMeanLongSun(t)
        let e = eccentricityEarthOrbit(t)
        let m = geomMeanAnomalySun(t)

        var y = tan(degToRad(epsilon) / 2.0)
        y *= y

        let sin2l0 = sin(2 * degToRad(l0))
        let sinm = sin(degToRad(m))
        let cos2l0 = cos(2 * degToRad(l0))
        let sin4l0 = sin(4 * degToRad(l0))
        let sin2m = sin(2 * degToRad(m))

        let eTime = y * sin2l0 - 2 * e * sinm + 4 * e * y * sinm * cos2l0
            - 0.5 * y * y * sin4l0 - 1.25 * e * e * sin2m
        return radToDeg(eTime) * 4.0
    }

    /// Hour angle (radians) of sunrise, using the standard atmospheric
    /// refraction + solar radius offset of 90.833°. `nil` if the sun never
    /// rises/sets that day at this latitude (polar conditions).
    private static func hourAngleSunrise(latitude: Double, solarDec: Double) -> Double? {
        let latRad = degToRad(latitude)
        let sdRad = degToRad(solarDec)
        let haArg = cos(degToRad(90.833)) / (cos(latRad) * cos(sdRad)) - tan(latRad) * tan(sdRad)
        guard haArg >= -1, haArg <= 1 else { return nil }
        return acos(haArg)
    }

    /// Minutes from UTC midnight of the given Julian Day at which sunrise
    /// occurs at the given coordinates. Iterates twice, as NOAA's reference
    /// implementation does, to refine accuracy.
    private static func sunriseUTCMinutes(jd: Double, latitude: Double, longitude: Double) -> Double? {
        var t = julianCentury(jd: jd)
        var eqTime = equationOfTime(t)
        var solarDec = sunDeclination(t)
        guard var hourAngle = hourAngleSunrise(latitude: latitude, solarDec: solarDec) else { return nil }
        hourAngle = -hourAngle
        var delta = longitude - radToDeg(hourAngle)
        var timeDiff = 4 * delta
        var timeUTC = 720 + timeDiff - eqTime

        // Second pass for better accuracy near the computed time.
        t = julianCentury(jd: jdFromJulianCentury(t) + timeUTC / 1440.0)
        eqTime = equationOfTime(t)
        solarDec = sunDeclination(t)
        guard var hourAngle2 = hourAngleSunrise(latitude: latitude, solarDec: solarDec) else { return nil }
        hourAngle2 = -hourAngle2
        delta = longitude - radToDeg(hourAngle2)
        timeDiff = 4 * delta
        timeUTC = 720 + timeDiff - eqTime

        return timeUTC
    }
}
