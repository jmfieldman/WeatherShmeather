//
//  PlaceForecastContentTests.swift
//  Copyright © 2026 WeatherShmeather.
//

import ForecastManager
import ForecastUIImpl
import Foundation
import PlacesManager
import PlacesManagerTestHelpers
import PreferencesManager
import PreferencesManagerTestHelpers
import Testing

struct PlaceForecastContentTests {
    private let now = Date(timeIntervalSince1970: 1_794_432_600)
    private let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    private func hour(_ offset: Int, celsius: Double = 20, chance: Int? = 0, usAqi: Int? = 40) -> HourlyForecast {
        HourlyForecast(
            time: now.addingTimeInterval(TimeInterval(offset * 3600) - 600),
            temperature: celsius,
            apparentTemperature: celsius,
            precipitationProbability: chance,
            precipitation: 0,
            weatherCode: .clear,
            windSpeed: 10,
            windDirection: 0,
            windGusts: 20,
            uvIndex: 3,
            visibility: 20000,
            humidity: 50,
            isDay: true,
            usAqi: usAqi,
            europeanAqi: 30,
        )
    }

    private func day(_ offset: Int, low: Double, high: Double, rain: Double = 0, chance: Int? = 0) -> DailyForecast {
        DailyForecast(
            date: now.addingTimeInterval(TimeInterval(offset * 86400)),
            weatherCode: .clear,
            high: high,
            low: low,
            sunrise: nil,
            sunset: nil,
            uvIndexMax: 4,
            precipitationSum: rain,
            precipitationHours: 0,
            precipitationProbabilityMax: chance,
            windSpeedMax: 30,
            windGustsMax: 40,
            windDirectionDominant: 180,
        )
    }

    private func forecast(
        hours: [HourlyForecast]? = nil,
        days: [DailyForecast]? = nil,
        minutely: [Double] = [0, 0, 0],
        airQuality: AirQuality? = AirQuality(usAqi: 62, europeanAqi: 46, pm25: 14.4, pm10: 15.2, ozone: 73),
    ) -> Forecast {
        Forecast(
            placeId: "p",
            fetchedAt: now,
            latitude: 34,
            longitude: -118,
            timeZone: timeZone,
            current: CurrentConditions(
                time: now,
                temperature: 30,
                apparentTemperature: 28,
                humidity: 20,
                isDay: true,
                weatherCode: .clear,
                precipitation: 0,
                cloudCover: 0,
                pressure: 1016,
                windSpeed: 5.9,
                windDirection: 225,
                windGusts: 6.8,
            ),
            hourly: hours ?? (0 ..< 30).map { hour($0) },
            daily: days ?? [day(0, low: 15, high: 30), day(1, low: 10, high: 20)],
            minutely: minutely.enumerated().map {
                MinutelyPrecipitation(time: now.addingTimeInterval(TimeInterval($0.offset * 900)), precipitation: $0.element)
            },
            airQuality: airQuality,
        )
    }

    private func make(_ forecast: Forecast, settings: UnitSettings = .testSettings(), isCurrentLocation: Bool = false) -> PlaceForecastContent {
        PlaceForecastContent.make(
            place: .testPlace(id: "p", name: "Tarzana", isCurrentLocation: isCurrentLocation),
            forecast: forecast,
            settings: settings,
            now: now,
        )
    }

    @Test func headerIsInTheUsersUnits() {
        let content = make(forecast(), settings: .testSettings(temperature: .fahrenheit), isCurrentLocation: true)

        #expect(content.header.name == "Tarzana")
        #expect(content.header.isCurrentLocation)
        #expect(content.header.temperature == "86°")
        #expect(content.header.condition == "Sunny")
        #expect(content.header.highLow.contains("86°") && content.header.highLow.contains("59°"))
    }

    @Test func hoursStartNowAndShowMeaningfulChances() {
        let hours = [hour(-2), hour(0, chance: 10), hour(1, chance: 40)] + (2 ..< 30).map { hour($0) }
        let content = make(forecast(hours: hours))

        #expect(content.hours.count == 24)
        #expect(content.hours.first?.label == "Now")
        #expect(content.hours[0].precipitationChance == nil)
        #expect(content.hours[1].precipitationChance == "40%")
    }

    @Test func nextTwoHoursOnlyWhenWet() {
        #expect(make(forecast(minutely: [0, 0, 0])).nextTwoHours == nil)

        let bars = make(forecast(minutely: [0, 0.5, 1.0])).nextTwoHours
        #expect(bars?.map(\.fraction) == [0, 0.5, 1])
    }

    @Test func dayRangesShareOneScale() throws {
        let content = make(forecast())
        let today = try #require(content.days.first)
        let tomorrow = try #require(content.days.last)

        #expect(today.weekday == "Today")
        // Across all days the range is 10° to 30°.
        #expect(today.rangeStart == 0.25 && today.rangeEnd == 1)
        #expect(tomorrow.rangeStart == 0 && tomorrow.rangeEnd == 0.5)
        #expect(today.currentMarker == 1)
        #expect(tomorrow.currentMarker == nil)
    }

    @Test func airQualityFollowsTheChosenScale() {
        let us = make(forecast(), settings: .testSettings(airQualityScale: .unitedStates)).airQuality
        #expect(us?.value == "62")
        #expect(us?.category == "Moderate")
        #expect(us?.upcoming.count == 8)

        let eu = make(forecast(), settings: .testSettings(airQualityScale: .european)).airQuality
        #expect(eu?.value == "46")
        #expect(eu?.category == "Moderate")

        #expect(make(forecast(airQuality: nil)).airQuality == nil)
    }

    @Test func aqiCategories() {
        #expect(PlaceForecastContent.usCategory(50) == "Good")
        #expect(PlaceForecastContent.usCategory(151) == "Unhealthy")
        #expect(PlaceForecastContent.europeanCategory(19) == "Good")
        #expect(PlaceForecastContent.europeanCategory(100) == "Extremely Poor")
    }

    @Test func compassPoints() {
        #expect(PlaceForecastContent.compassPoint(degrees: 0) == "N")
        #expect(PlaceForecastContent.compassPoint(degrees: 225) == "SW")
        #expect(PlaceForecastContent.compassPoint(degrees: 359) == "N")
        #expect(PlaceForecastContent.compassPoint(degrees: -90) == "W")
    }

    @Test func precipitationOutlookNamesTheNextWetDay() {
        let dry = make(forecast())
        #expect(dry.precipitation.outlook == "None expected in the next 16 days.")

        let wet = make(forecast(days: [day(0, low: 10, high: 20), day(1, low: 10, high: 20), day(2, low: 10, high: 20, rain: 4)]))
        #expect(wet.precipitation.outlook.hasPrefix("Next expected"))
    }
}
