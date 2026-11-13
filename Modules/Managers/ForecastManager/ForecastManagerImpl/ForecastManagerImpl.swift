//
//  ForecastManagerImpl.swift
//  Copyright © 2026 WeatherShmeather.
//

import AppEnvironment
import DeviceLocationManager
import ForecastManager
import ForecastModels
import Foundation
import Inject
import Logging
import NetworkManager
import PlacesManager
import Slate
import SlateManager
import SwiftAsyncEx
import UIKit

/// How old a forecast may get before a trigger refetches it.
let kForecastMaxAge: TimeInterval = 15 * 60

/// How far a place may move before its forecast is for the wrong spot.
private let kForecastLocationTolerance: Double = 1000

@MainActor
public final class ForecastManagerImpl: ForecastManager {
    private let appEnvironment: AppEnvironment = Inject()
    private let networkManager: NetworkManager = Inject()
    private let slateManager: SlateManager = Inject()
    private let placesManager: PlacesManager = Inject()

    private let slate: Slate<ForecastSlateSchema>
    private let now: @Sendable () -> Date

    private let mutableForecasts = MutableProperty<[String: Forecast]>([:])
    public private(set) lazy var forecasts = Property(mirroring: mutableForecasts)

    private let mutableRefreshingPlaceIds = MutableProperty<Set<String>>([])
    public private(set) lazy var refreshingPlaceIds =
        Property(mirroring: mutableRefreshingPlaceIds)

    private let mutableRefreshErrors = MutableProperty<[String: ForecastError]>([:])
    public private(set) lazy var refreshErrors =
        Property(mirroring: mutableRefreshErrors)

    /// One fetch per place at a time; a second request joins the first.
    private var inFlight: [String: Task<Void, Never>] = [:]

    /// Writes for places removed while their fetch was in flight are dropped.
    private var knownPlaceIds: Set<String> = []

    /// - Parameter now: The clock, so tests can age a forecast.
    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
        self.slate = slateManager.provide(for: ForecastSlateSchema.self)

        // Signed out, there are no places and nothing to fetch.
        guard appEnvironment.userId != nil else {
            return
        }

        Task.bound(to: self) { @MainActor [weak self] in
            await self?.loadCache()
            self?.followPlaces()
        }
        refreshOnForeground()
    }

    // MARK: Cache

    /// Republishes every stored forecast, so the first screen shows the last
    /// known weather before any network call returns.
    private func loadCache() async {
        do {
            let (summaries, hourly, daily, minutely) = try await slate.query { context in
                try (
                    context[StoredForecastSummary.self].many(),
                    context[StoredHourlyForecast.self].sort([.asc(\.time)]).many(),
                    context[StoredDailyForecast.self].sort([.asc(\.date)]).many(),
                    context[StoredMinutelyPrecipitation.self].sort([.asc(\.time)]).many(),
                )
            }
            let hourlyByPlace = Dictionary(grouping: hourly, by: \.placeId)
            let dailyByPlace = Dictionary(grouping: daily, by: \.placeId)
            let minutelyByPlace = Dictionary(grouping: minutely, by: \.placeId)

            var forecasts = mutableForecasts.value
            for summary in summaries where forecasts[summary.placeId] == nil {
                forecasts[summary.placeId] = Forecast(
                    summary: summary,
                    hourly: hourlyByPlace[summary.placeId] ?? [],
                    daily: dailyByPlace[summary.placeId] ?? [],
                    minutely: minutelyByPlace[summary.placeId] ?? [],
                )
            }
            mutableForecasts.value = forecasts
        } catch {
            Log(.forecast, .error, "Couldn't read cached forecasts: \(error.localizedDescription)")
        }
    }

    // MARK: Following the places list

    private func followPlaces() {
        Task.observe(bindTo: self) { [placesManager] in
            (placesManager.hasLoaded.value, placesManager.places.value)
        } perform: { [weak self] hasLoaded, places in
            guard hasLoaded else {
                return
            }

            self?.placesChanged(places)
        }
    }

    private func placesChanged(_ places: [Place]) {
        knownPlaceIds = Set(places.map(\.id))

        let removed = Set(mutableForecasts.value.keys).subtracting(knownPlaceIds)
        if !removed.isEmpty {
            Task.bound(to: self) { @MainActor [weak self] in
                await self?.deleteForecasts(placeIds: removed)
            }
        }

        // New places, and places that moved, need weather now; the rest only
        // if they've gone stale.
        for place in places {
            if let forecast = mutableForecasts.value[place.id], !Self.hasMoved(place, from: forecast) {
                refreshIfStale(placeId: place.id)
            } else {
                startFetch(for: place)
            }
        }
    }

    private static func hasMoved(_ place: Place, from forecast: Forecast) -> Bool {
        let placeCoordinate = Coordinate(latitude: place.latitude, longitude: place.longitude)
        let forecastCoordinate = Coordinate(latitude: forecast.latitude, longitude: forecast.longitude)
        return placeCoordinate.distance(to: forecastCoordinate) > kForecastLocationTolerance
    }

    private func refreshOnForeground() {
        Task.bound(to: self) { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.willEnterForegroundNotification,
            ) {
                self?.refreshAllIfStale()
            }
        }
    }

    // MARK: Refreshing

    public func refreshIfStale(placeId: String) {
        guard let place = place(id: placeId) else {
            return
        }

        if let forecast = mutableForecasts.value[placeId], now().timeIntervalSince(forecast.fetchedAt) < kForecastMaxAge {
            return
        }

        startFetch(for: place)
    }

    public func refreshAllIfStale() {
        for place in placesManager.places.value {
            refreshIfStale(placeId: place.id)
        }
    }

    public func refreshAll() async {
        let tasks = placesManager.places.value.map { startFetch(for: $0) }
        for task in tasks {
            await task.value
        }
    }

    private func place(id: String) -> Place? {
        placesManager.places.value.first { $0.id == id }
    }

    @discardableResult
    private func startFetch(for place: Place) -> Task<Void, Never> {
        if let existing = inFlight[place.id] {
            return existing
        }

        mutableRefreshingPlaceIds.value.insert(place.id)
        let task = Task { @MainActor [weak self] in
            await self?.fetch(place)
            self?.inFlight[place.id] = nil
            self?.mutableRefreshingPlaceIds.value.remove(place.id)
        }
        task.bind(to: self)
        inFlight[place.id] = task
        return task
    }

    private func fetch(_ place: Place) async {
        let fetchedAt = now()
        do {
            // Both requests run at once. Air quality is optional: a failure
            // there still saves the forecast, without air quality.
            async let airQuality = fetchAirQuality(for: place)
            let response = try await networkManager.request(
                resource: GetForecastResource(),
                with: ForecastRequest(latitude: place.latitude, longitude: place.longitude),
            )
            let forecast = await Forecast(
                placeId: place.id,
                fetchedAt: fetchedAt,
                latitude: place.latitude,
                longitude: place.longitude,
                response: response,
                airQuality: airQuality,
            )

            guard knownPlaceIds.contains(place.id) else {
                return
            }

            try await save(forecast)
            mutableForecasts.value[place.id] = forecast
            mutableRefreshErrors.value[place.id] = nil
        } catch let error as NetworkError {
            Log(.forecast, .warning, "Fetching a forecast failed: \(error.debugDescription)")
            mutableRefreshErrors.value[place.id] = error.isConnectivityFailure ? .offline : .failed
        } catch {
            Log(.forecast, .error, "Saving a forecast failed: \(error.localizedDescription)")
            mutableRefreshErrors.value[place.id] = .failed
        }
    }

    private func fetchAirQuality(for place: Place) async -> AirQualityResponse? {
        do {
            return try await networkManager.request(
                resource: GetAirQualityResource(),
                with: AirQualityRequest(latitude: place.latitude, longitude: place.longitude),
            )
        } catch {
            Log(.forecast, .info, "No air quality for a place: \(error.debugDescription)")
            return nil
        }
    }

    // MARK: Storage

    /// Replaces a place's rows in every table in one transaction, so a reader
    /// never sees a mix of old and new.
    private func save(_ forecast: Forecast) async throws {
        try await slate.mutate { context in
            let placeId = forecast.placeId
            _ = try context[DatabaseStoredHourlyForecast.self].delete(where: \.placeId == placeId)
            _ = try context[DatabaseStoredDailyForecast.self].delete(where: \.placeId == placeId)
            _ = try context[DatabaseStoredMinutelyPrecipitation.self].delete(where: \.placeId == placeId)

            let summary = try context[DatabaseStoredForecastSummary.self].firstOrCreate(\.placeId, placeId)
            summary.fetchedAt = forecast.fetchedAt
            summary.latitude = forecast.latitude
            summary.longitude = forecast.longitude
            summary.timeZoneIdentifier = forecast.timeZone.identifier
            summary.currentTime = forecast.current.time
            summary.temperature = forecast.current.temperature
            summary.apparentTemperature = forecast.current.apparentTemperature
            summary.humidity = forecast.current.humidity
            summary.isDay = forecast.current.isDay
            summary.weatherCode = forecast.current.weatherCode.wmoCode
            summary.precipitation = forecast.current.precipitation
            summary.cloudCover = forecast.current.cloudCover
            summary.pressure = forecast.current.pressure
            summary.windSpeed = forecast.current.windSpeed
            summary.windDirection = forecast.current.windDirection
            summary.windGusts = forecast.current.windGusts
            summary.usAqi = forecast.airQuality?.usAqi.map(Int64.init)
            summary.europeanAqi = forecast.airQuality?.europeanAqi.map(Int64.init)
            summary.pm25 = forecast.airQuality?.pm25
            summary.pm10 = forecast.airQuality?.pm10
            summary.ozone = forecast.airQuality?.ozone

            for hour in forecast.hourly {
                let row = context.create(DatabaseStoredHourlyForecast.self)
                row.placeId = placeId
                row.time = hour.time
                row.temperature = hour.temperature
                row.apparentTemperature = hour.apparentTemperature
                row.precipitationProbability = hour.precipitationProbability.map(Int64.init)
                row.precipitation = hour.precipitation
                row.weatherCode = hour.weatherCode.wmoCode
                row.windSpeed = hour.windSpeed
                row.windDirection = hour.windDirection
                row.windGusts = hour.windGusts
                row.uvIndex = hour.uvIndex
                row.visibility = hour.visibility
                row.humidity = hour.humidity
                row.isDay = hour.isDay
                row.usAqi = hour.usAqi.map(Int64.init)
                row.europeanAqi = hour.europeanAqi.map(Int64.init)
            }

            for day in forecast.daily {
                let row = context.create(DatabaseStoredDailyForecast.self)
                row.placeId = placeId
                row.date = day.date
                row.weatherCode = day.weatherCode.wmoCode
                row.high = day.high
                row.low = day.low
                row.sunrise = day.sunrise
                row.sunset = day.sunset
                row.uvIndexMax = day.uvIndexMax
                row.precipitationSum = day.precipitationSum
                row.precipitationHours = day.precipitationHours
                row.precipitationProbabilityMax = day.precipitationProbabilityMax.map(Int64.init)
                row.windSpeedMax = day.windSpeedMax
                row.windGustsMax = day.windGustsMax
                row.windDirectionDominant = day.windDirectionDominant
            }

            for step in forecast.minutely {
                let row = context.create(DatabaseStoredMinutelyPrecipitation.self)
                row.placeId = placeId
                row.time = step.time
                row.precipitation = step.precipitation
            }
        }
    }

    private func deleteForecasts(placeIds: Set<String>) async {
        for placeId in placeIds {
            mutableForecasts.value[placeId] = nil
            mutableRefreshErrors.value[placeId] = nil
        }

        let ids = Array(placeIds)
        do {
            try await slate.mutate { context in
                _ = try context[DatabaseStoredForecastSummary.self].delete(where: .in(\.placeId, ids))
                _ = try context[DatabaseStoredHourlyForecast.self].delete(where: .in(\.placeId, ids))
                _ = try context[DatabaseStoredDailyForecast.self].delete(where: .in(\.placeId, ids))
                _ = try context[DatabaseStoredMinutelyPrecipitation.self].delete(where: .in(\.placeId, ids))
            }
        } catch {
            Log(.forecast, .error, "Couldn't delete forecasts: \(error.localizedDescription)")
        }
    }
}
