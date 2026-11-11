# WeatherShmeather Product Spec

What the app does, screen by screen, and which architectural idea each feature is there to show. The engineering side is in [engineering/IOS-ARCHITECTURE.md](engineering/IOS-ARCHITECTURE.md).

Last updated: 2026-11-11

## Purpose

WeatherShmeather is a demo. It is a small, complete weather app whose real job is to be a readable example of an iOS app architecture. Features are chosen because each one exercises a pattern clearly: networking against a real API, tabular data in Slate, single values in `PersistentProperty`, reactive state in `Property` / `MutableProperty`, and per-user environments. When a feature would add breadth without teaching anything new, it is left out.

All weather data comes from [Open-Meteo](https://open-meteo.com/), which is free and needs no API key.

## Users and sign-in

- The first screen asks for a username. There is no password and no server account; the normalized username **is** the user id.
- Usernames are trimmed and lowercased, limited to letters, digits, `-` and `_`, and 1 to 32 characters. The sign-in button is enabled only for a valid name.
- Below the field, the users who have signed in on this device are listed, so switching back to one is a tap.
- Each user has entirely separate places, preferences, and cached weather. Signing in as a different user shows none of the previous user's data.
- Signing out returns to the sign-in screen and keeps the user's data, so signing back in restores it. Swiping a user in the known-users list offers to remove them from the device, which deletes their data.
- The app remembers who was signed in and restores them at launch without showing sign-in.

**Demonstrates:** the per-user `AppEnvironment` and the injection-container rebuild on sign-in and sign-out; the cross-user store for the current user and known users.

## Places

A user's places are one list, stored in one Slate table:

- **Current location.** At most one row has `isCurrentLocation = true`. It always sorts first, can't be deleted or reordered, and is hidden entirely while location permission isn't granted. When the device's location changes meaningfully (more than about a kilometer), the places manager overwrites that row's coordinates and name, and its forecast is refetched. Its name comes from reverse geocoding on device through MapKit, because Open-Meteo has no reverse geocoding.
- **Saved places.** Rows the user added through search, in the user's own order.

Location permission is "When In Use", asked the first time the Places list appears. Denying it simply means no current-location row; a footer row explains how to turn it on in Settings.

A new user starts with no saved places. With permission denied and nothing saved, the Places list shows an empty state that leads to Manage Places.

**Demonstrates:** a Slate table with a flag column the manager treats specially; a manager driven by a CoreLocation stream; cross-manager reaction (the forecast manager observing the places list).

## Screens

The root is a tab bar with two tabs: **Weather** and **Settings**.

### Sign In

Username field, sign-in button, and the known-users list. Presented full screen over the tabs whenever no one is signed in.

### Places (Weather tab root)

A list of the user's places, current location first. Each row shows the place name, the current temperature and condition icon, and today's high and low. Pull to refresh refetches every place. An Edit button in the navigation bar opens Manage Places. Tapping a row opens Place Forecast.

Rows show cached data immediately and update in place when a refresh finishes. A row whose data is older than an hour shows how old it is.

### Place Forecast

One place in full detail, as a scrolling page of sections:

- **Now.** Temperature, feels-like, condition, today's high and low, and is-day styling.
- **Next hour precipitation.** The 15-minute precipitation for the next two hours as a small bar chart, shown only when any precipitation is expected.
- **Hourly.** A horizontal strip of the next 48 hours: time, condition icon, temperature, precipitation probability.
- **Daily.** The next 16 days: weekday, condition icon, precipitation probability, low and high on a shared range bar.
- **Wind.** Current speed, gusts, and direction; today's maximum.
- **Precipitation.** Today's total, precipitation hours, and the next day with meaningful precipitation.
- **Air quality.** The current AQI on the user's chosen scale with its category, the main pollutants (PM2.5, PM10, ozone), and the AQI for the next 24 hours. Air quality coverage varies by region; a place with no data hides the section.
- **Details.** Humidity, pressure, UV index, visibility, sunrise and sunset.

Swiping horizontally pages between places in list order.

### Manage Places

Reached from Edit on Places. Shows the saved places with delete and reorder, plus a search field at the top. This is the only search in the app.

- Typing searches Open-Meteo's geocoding API after a short pause, showing name, region, and country for each result.
- Tapping a result adds it to the end of the list and clears the search. A place already saved shows a checkmark instead.
- The current-location row appears, fixed at the top, but can't be edited.

**Demonstrates:** debounced input driving a `SerialTask`; in-memory results in a `MutableProperty`; writing to Slate and republishing.

### Settings (Settings tab root)

- **Units:** temperature (°C, °F), wind speed (km/h, m/s, mph, knots), precipitation (mm, inches), pressure (hPa, inHg).
- **Display:** time format (system, 12-hour, 24-hour), AQI scale (US, European).
- **Account:** the signed-in username and Sign Out.

Every setting takes effect everywhere immediately, with no refetch.

**Demonstrates:** one `PersistentProperty` per setting; derived display values with `Property(tracking:)`.

## Weather data

Data is always fetched in Open-Meteo's metric defaults (°C, km/h, mm, hPa) with `timezone=auto`, stored in those units, and converted for display. That is why changing a unit never refetches.

| Open-Meteo API | Data fetched |
|---|---|
| Forecast, `current` | temperature, apparent temperature, humidity, is day, weather code, precipitation, cloud cover, pressure, wind speed, direction, gusts |
| Forecast, `minutely_15` | precipitation (next 2 hours) |
| Forecast, `hourly` | temperature, apparent temperature, precipitation probability, precipitation, weather code, wind speed, direction, gusts, UV index, visibility, humidity, is day (48 hours) |
| Forecast, `daily` | weather code, temperature max and min, sunrise, sunset, UV index max, precipitation sum, precipitation hours, precipitation probability max, wind speed max, gusts max, dominant direction (16 days) |
| Air quality, `current` and `hourly` | US AQI, European AQI, PM2.5, PM10, ozone (24 hours) |
| Geocoding, `search` | Place search in Manage Places |

The exact variable names are checked against Open-Meteo's documentation when the network resources are written.

### Freshness

- Weather for a place is cached in Slate and shown immediately at launch, even offline.
- A place's weather is refetched when it is older than 15 minutes and the app comes to the foreground, the Places list appears, or the place's forecast is opened. Pull to refresh always refetches.
- Adding a place fetches its weather at once. Removing a place deletes its weather.
- A failed refresh leaves the cached data on screen and shows a small, dismissible error banner; a place with no cached data shows a retry state.

## Out of scope

- Real authentication, accounts, or sync between devices.
- Widgets, notifications, severe-weather alerts, and maps or radar.
- Historical weather, marine, and other Open-Meteo APIs beyond the three above.
- iPad, landscape, and localization beyond English (strings still go through resources).
- Migrating saved places across schema changes; a schema change loses them (see the architecture doc).
