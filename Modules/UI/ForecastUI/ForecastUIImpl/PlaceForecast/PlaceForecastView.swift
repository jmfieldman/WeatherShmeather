//
//  PlaceForecastView.swift
//  Copyright © 2026 WeatherShmeather.
//

import DesignSystem
import ForecastManager
import ForecastUIResources
import SFSafeSymbols
import SwiftAsyncEx
import SwiftUI
import SwiftUIEx
import WeatherDisplay

@Observable @MainActor
public final class PlaceForecastViewModel {
    public enum State: Equatable, Sendable {
        case loading(name: String)
        case failed(name: String, message: String)
        case loaded(PlaceForecastContent)
    }

    /// What the Conditions strip shows.
    public enum Metric: Hashable, CaseIterable, Sendable {
        case temperature
        case precipitation
        case wind
    }

    public let state: Property<State>
    public let metric: Property<Metric>

    public let metricTask: SerialTask<Metric, Void>
    public let retryTask: SerialTask<Void, Void>

    public init(
        state: Property<State> = .constant(.loading(name: "")),
        metric: Property<Metric> = .constant(.temperature),
        metricTask: SerialTask<Metric, Void> = SerialTask { _ in },
        retryTask: SerialTask<Void, Void> = SerialTask {},
    ) {
        self.state = state
        self.metric = metric
        self.metricTask = metricTask
        self.retryTask = retryTask
    }
}

public struct PlaceForecastView: HostedView {
    let viewModel: PlaceForecastViewModel

    public init(viewModel: PlaceForecastViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            background.ignoresSafeArea()
            switch viewModel.state.value {
            case let .loading(name):
                placeholder(name: name) { ProgressView().tint(ConditionPalette.foreground) }

            case let .failed(name, message):
                placeholder(name: name) {
                    VStack(spacing: .m) {
                        Text(message)
                            .textStyle(.callout, color: ConditionPalette.secondaryForeground)
                            .multilineTextAlignment(.center)
                        ActionButton(String.ForecastUI.forecastRetry, task: viewModel.retryTask, variant: .secondary)
                            .frame(maxWidth: Layout.retryButtonWidth)
                    }
                }

            case let .loaded(content):
                ForecastContentView(content: content, metric: metric)
            }
        }
        .animation(.default, value: backgroundKey)
    }

    /// The strip's picker shows the screen's metric and reports picks as requests.
    private var metric: Binding<PlaceForecastViewModel.Metric> {
        Binding(get: { viewModel.metric.value }, set: { viewModel.metricTask.fire($0) })
    }

    private var background: Color {
        if case let .loaded(content) = viewModel.state.value {
            return content.weatherCode.background(isDay: content.isDay)
        }
        return ConditionPalette.cloudyDay
    }

    private var backgroundKey: String {
        if case let .loaded(content) = viewModel.state.value {
            return "\(content.weatherCode)-\(content.isDay)"
        }
        return "none"
    }

    private func placeholder(name: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: .l) {
            Text(name)
                .textStyle(.hero, color: ConditionPalette.foreground)
            content()
        }
        .padding(.horizontal, .xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The page's fixed sizes, named so the layout reads as intent.
private enum Layout {
    static let retryButtonWidth: CGFloat = 200
    static let metricPickerWidth: CGFloat = 150
    static let hourSymbolHeight: CGFloat = 44
    static let hourColumnMinWidth: CGFloat = 44
    static let precipitationChartHeight: CGFloat = 60
    static let weekdayWidth: CGFloat = 56
    static let dayColumnWidth: CGFloat = 40
    static let dayRowHeight: CGFloat = 52
    static let rangeBarHeight: CGFloat = 6
    static let markerSize: CGFloat = 8
}

// MARK: - Content

private struct ForecastContentView: View {
    let content: PlaceForecastContent
    @Binding var metric: PlaceForecastViewModel.Metric

    var body: some View {
        ScrollView {
            VStack(spacing: .m) {
                HeaderView(header: content.header)
                    .padding(.top, .xl)
                    .padding(.bottom, .l)
                ConditionsSection(hours: content.hours, metric: $metric)
                if let bars = content.nextTwoHours {
                    NextHoursSection(bars: bars)
                }
                DailySection(days: content.days)
                if let airQuality = content.airQuality {
                    AirQualitySection(airQuality: airQuality)
                }
                HStack(alignment: .top, spacing: .m) {
                    WindSection(wind: content.wind)
                    PrecipitationSection(precipitation: content.precipitation)
                }
                DetailsSection(details: content.details)
            }
            .padding(.horizontal, .gutter)
            // Room to scroll the last section above the pager's bottom bar.
            .padding(.bottom, .xxl + .xl)
        }
        .scrollIndicators(.hidden)
    }
}

private struct HeaderView: View {
    let header: PlaceForecastContent.Header

    var body: some View {
        VStack(spacing: .xxs) {
            if header.isCurrentLocation {
                Label(String.ForecastUI.forecastMyLocation, systemSymbol: .locationFill)
                    .labelStyle(.titleAndIcon)
                    .textStyle(.caption, color: ConditionPalette.foreground)
                    .textCase(.uppercase)
            }
            Text(header.name)
                .textStyle(.hero, color: ConditionPalette.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(header.temperature)
                .font(TextStyle.display.font)
                .foregroundStyle(ConditionPalette.foreground)
                .monospacedDigit()
            Text(header.condition)
                .textStyle(.title, color: ConditionPalette.foreground)
            Text(header.highLow)
                .textStyle(.title, color: ConditionPalette.foreground)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A titled section card on the page's condition color.
private struct ForecastSection<Content: View, Accessory: View>: View {
    let title: String
    let symbol: SFSymbol
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        symbol: SFSymbol,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        self.symbol = symbol
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .s) {
            HStack {
                Label(title, systemSymbol: symbol)
                    .textStyle(.caption, color: ConditionPalette.secondaryForeground)
                    .textCase(.uppercase)
                Spacer(minLength: .s)
                accessory()
            }
            content()
        }
        .padding(.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ConditionPalette.cardFill, in: .rect(cornerRadius: Radius.card))
    }
}

// MARK: - Conditions

private struct ConditionsSection: View {
    let hours: [PlaceForecastContent.HourColumn]
    @Binding var metric: PlaceForecastViewModel.Metric

    var body: some View {
        ForecastSection(String.ForecastUI.forecastConditionsTitle, symbol: .clock) {
            Picker(String.ForecastUI.forecastConditionsTitle, selection: $metric) {
                Image(systemSymbol: .thermometerMedium)
                    .accessibilityLabel(String.ForecastUI.forecastMetricTemperature)
                    .tag(PlaceForecastViewModel.Metric.temperature)
                Image(systemSymbol: .dropFill)
                    .accessibilityLabel(String.ForecastUI.forecastMetricPrecipitation)
                    .tag(PlaceForecastViewModel.Metric.precipitation)
                Image(systemSymbol: .wind)
                    .accessibilityLabel(String.ForecastUI.forecastMetricWind)
                    .tag(PlaceForecastViewModel.Metric.wind)
            }
            .pickerStyle(.segmented)
            .frame(width: Layout.metricPickerWidth)
        } content: {
            ScrollView(.horizontal) {
                HStack(spacing: .l) {
                    ForEach(hours) { hour in
                        column(hour)
                    }
                }
                .padding(.vertical, .xs)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func column(_ hour: PlaceForecastContent.HourColumn) -> some View {
        VStack(spacing: .s) {
            Text(hour.label)
                .textStyle(.callout, color: ConditionPalette.foreground)
            Group {
                switch metric {
                case .temperature:
                    VStack(spacing: .xxs) {
                        ConditionSymbol(code: hour.weatherCode, isDay: hour.isDay)
                        Text(hour.precipitationChance ?? " ")
                            .textStyle(.finePrint, color: ConditionPalette.precipitation)
                    }

                case .precipitation:
                    Image(systemSymbol: .dropFill)
                        .foregroundStyle(ConditionPalette.foreground)

                case .wind:
                    Image(systemSymbol: .arrowUp)
                        // Arrows point where the wind blows to, opposite its source.
                        .rotationEffect(.degrees(hour.windDirectionDegrees + 180))
                        .foregroundStyle(ConditionPalette.foreground)
                }
            }
            .font(TextStyle.title.font)
            .frame(height: Layout.hourSymbolHeight)
            Text(value(for: hour))
                .textStyle(.headline, color: ConditionPalette.foreground)
                .monospacedDigit()
        }
        .frame(minWidth: Layout.hourColumnMinWidth)
    }

    private func value(for hour: PlaceForecastContent.HourColumn) -> String {
        switch metric {
        case .temperature: hour.temperature
        case .precipitation: hour.precipitationAmount
        case .wind: hour.windSpeed
        }
    }
}

// MARK: - Next two hours

private struct NextHoursSection: View {
    let bars: [PlaceForecastContent.PrecipitationBar]

    var body: some View {
        ForecastSection(String.ForecastUI.forecastNextHoursTitle, symbol: .umbrellaFill) {
            Text(String.ForecastUI.forecastNextHoursRain)
                .textStyle(.callout, color: ConditionPalette.foreground)
            HStack(alignment: .bottom, spacing: .xs) {
                ForEach(bars) { bar in
                    RoundedRectangle(cornerRadius: .xs)
                        .fill(ConditionPalette.foreground)
                        .frame(height: max(.xs, Layout.precipitationChartHeight * bar.fraction))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(bar.label)
                }
            }
            .frame(height: Layout.precipitationChartHeight, alignment: .bottom)
            if let first = bars.first, let last = bars.last {
                HStack {
                    Text(first.label)
                    Spacer()
                    Text(last.label)
                }
                .textStyle(.finePrint, color: ConditionPalette.secondaryForeground)
            }
        }
    }
}

// MARK: - Daily

private struct DailySection: View {
    let days: [PlaceForecastContent.DayRow]

    var body: some View {
        ForecastSection(String.ForecastUI.forecastDailyTitle, symbol: .calendar) {
            VStack(spacing: 0) {
                ForEach(days) { day in
                    row(day)
                    if day.id != days.last?.id {
                        Rectangle()
                            .fill(ConditionPalette.subtleForeground)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private func row(_ day: PlaceForecastContent.DayRow) -> some View {
        HStack(spacing: .m) {
            Text(day.weekday)
                .textStyle(.headline, color: ConditionPalette.foreground)
                .frame(width: Layout.weekdayWidth, alignment: .leading)
            VStack(spacing: 0) {
                ConditionSymbol(code: day.weatherCode, isDay: true)
                    .font(TextStyle.title.font)
                if let chance = day.precipitationChance {
                    Text(chance)
                        .textStyle(.finePrint, color: ConditionPalette.precipitation)
                }
            }
            .frame(width: Layout.dayColumnWidth)
            Text(day.low)
                .textStyle(.headline, color: ConditionPalette.secondaryForeground)
                .monospacedDigit()
                .frame(width: Layout.dayColumnWidth, alignment: .trailing)
            RangeBar(start: day.rangeStart, end: day.rangeEnd, marker: day.currentMarker)
            Text(day.high)
                .textStyle(.headline, color: ConditionPalette.foreground)
                .monospacedDigit()
                .frame(width: Layout.dayColumnWidth, alignment: .trailing)
        }
        .frame(minHeight: Layout.dayRowHeight)
        .accessibilityElement(children: .combine)
    }
}

/// A day's low-to-high span on the shared scale of all days shown.
private struct RangeBar: View {
    let start: Double
    let end: Double
    let marker: Double?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ConditionPalette.subtleForeground)
                Capsule()
                    .fill(TemperatureGradient.gradient)
                    .frame(width: max(width * (end - start), Layout.rangeBarHeight))
                    .offset(x: width * start)
                if let marker {
                    Circle()
                        .fill(ConditionPalette.foreground)
                        .overlay(Circle().stroke(DesignTokens.softShadow, lineWidth: 1))
                        .frame(width: Layout.markerSize, height: Layout.markerSize)
                        .offset(x: min(max(width * marker - Layout.markerSize / 2, 0), width - Layout.markerSize))
                }
            }
        }
        .frame(height: Layout.rangeBarHeight)
    }
}

/// Cool to warm, for range bars.
private enum TemperatureGradient {
    static let gradient = LinearGradient(
        colors: [Color(uiColor: .systemTeal), Color(uiColor: .systemYellow), Color(uiColor: .systemOrange)],
        startPoint: .leading,
        endPoint: .trailing,
    )
}

// MARK: - Air quality

private struct AirQualitySection: View {
    let airQuality: PlaceForecastContent.AirQualityContent

    var body: some View {
        ForecastSection(String.ForecastUI.forecastAirQualityTitle, symbol: .aqiMedium) {
            HStack(alignment: .firstTextBaseline, spacing: .s) {
                Text(airQuality.value)
                    .font(TextStyle.cardTemperature.font)
                    .foregroundStyle(ConditionPalette.foreground)
                VStack(alignment: .leading) {
                    Text(airQuality.category)
                        .textStyle(.headline, color: ConditionPalette.foreground)
                    Text(airQuality.scaleName)
                        .textStyle(.caption, color: ConditionPalette.secondaryForeground)
                }
            }
            RangeBar(start: 0, end: 1, marker: airQuality.fraction)
                .padding(.vertical, .xs)
            HStack {
                ForEach(airQuality.pollutants) { reading in
                    VStack(alignment: .leading, spacing: .xxs) {
                        Text(reading.name)
                            .textStyle(.caption, color: ConditionPalette.secondaryForeground)
                        Text(reading.value)
                            .textStyle(.callout, color: ConditionPalette.foreground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !airQuality.upcoming.isEmpty {
                Text(String.ForecastUI.forecastAirQualityNextHours)
                    .textStyle(.caption, color: ConditionPalette.secondaryForeground)
                    .padding(.top, .s)
                HStack {
                    ForEach(airQuality.upcoming) { reading in
                        VStack(spacing: .xxs) {
                            Text(reading.name)
                                .textStyle(.finePrint, color: ConditionPalette.secondaryForeground)
                            Text(reading.value)
                                .textStyle(.callout, color: ConditionPalette.foreground)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Wind and precipitation

private struct WindSection: View {
    let wind: PlaceForecastContent.WindContent

    var body: some View {
        ForecastSection(String.ForecastUI.forecastWindTitle, symbol: .wind) {
            HStack(spacing: .s) {
                Image(systemSymbol: .arrowUp)
                    .rotationEffect(.degrees(wind.directionDegrees + 180))
                    .font(TextStyle.title.font)
                    .foregroundStyle(ConditionPalette.foreground)
                    .accessibilityLabel(wind.direction)
                Text(wind.speed)
                    .textStyle(.title, color: ConditionPalette.foreground)
            }
            pair(String.ForecastUI.forecastWindGusts, wind.gusts)
            pair(String.ForecastUI.forecastWindDirection, wind.direction)
            pair(String.ForecastUI.forecastWindTodayMax, wind.todayMax)
        }
    }
}

private struct PrecipitationSection: View {
    let precipitation: PlaceForecastContent.PrecipitationContent

    var body: some View {
        ForecastSection(String.ForecastUI.forecastPrecipitationTitle, symbol: .dropFill) {
            Text(precipitation.today)
                .textStyle(.title, color: ConditionPalette.foreground)
            Text(String.ForecastUI.forecastPrecipitationToday)
                .textStyle(.caption, color: ConditionPalette.secondaryForeground)
            Spacer(minLength: 0)
            Text(precipitation.outlook)
                .textStyle(.callout, color: ConditionPalette.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
private func pair(_ title: String, _ value: String) -> some View {
    HStack {
        Text(title)
            .textStyle(.caption, color: ConditionPalette.secondaryForeground)
        Spacer(minLength: .xs)
        Text(value)
            .textStyle(.callout, color: ConditionPalette.foreground)
    }
}

// MARK: - Details

private struct DetailsSection: View {
    let details: [PlaceForecastContent.Detail]

    var body: some View {
        ForecastSection(String.ForecastUI.forecastDetailsTitle, symbol: .listBullet) {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: .m) {
                ForEach(details) { detail in
                    VStack(alignment: .leading, spacing: .xxs) {
                        Text(detail.title)
                            .textStyle(.caption, color: ConditionPalette.secondaryForeground)
                        Text(detail.value)
                            .textStyle(.title, color: ConditionPalette.foreground)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview("Loading") {
    PlaceForecastView(viewModel: PlaceForecastViewModel(state: .constant(.loading(name: "Tarzana"))))
}

#Preview("Failed") {
    PlaceForecastView(viewModel: PlaceForecastViewModel(
        state: .constant(.failed(name: "Tarzana", message: "Check your connection and try again.")),
    ))
}
