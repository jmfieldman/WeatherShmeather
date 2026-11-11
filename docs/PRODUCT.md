# WeatherShmeather Product Spec

What the app does, screen by screen, and which architectural idea each feature is there to show. The engineering side is in [engineering/IOS-ARCHITECTURE.md](engineering/IOS-ARCHITECTURE.md).

Last updated: 2026-11-11

## Purpose

WeatherShmeather is a demo. It is a small, complete weather app whose real job is to be a readable example of an iOS app architecture. Features are chosen because each one exercises a pattern clearly: networking against a real API, tabular data in Slate, single values in `PersistentProperty`, reactive state in `Property` / `MutableProperty`, and per-user environments. When a feature would add breadth without teaching anything new, it is left out.

All weather data comes from [Open-Meteo](https://open-meteo.com/), which is free and needs no API key.

## Users and sign-in

- The sign-in screen is the app's root. It asks for a username in a free-form text field. There is no password and no server account; the normalized username **is** the user id.
- Usernames are trimmed and lowercased, limited to letters, digits, `-` and `_`, start with a letter or digit, and are 1 to 32 characters. Names starting with `_` are reserved for the app's own silos. The sign-in button is enabled only for a valid name.
- Below the field, the last five usernames that signed in on this device are listed, most recent first. Tapping one signs in as that user.
- Signing in presents the weather experience full screen over the sign-in screen.
- Each user has entirely separate places, preferences, and cached weather. Signing in as a different user shows none of the previous user's data.
- **Log Out**, in the Places list's menu, dismisses the weather experience back to the sign-in screen. The user's data stays on the device, so signing back in restores it.
- On a cold launch with a signed-in user, the sign-in screen is still the root, but the weather experience is presented over it without animation, so the user lands straight in the app. Logging out reveals the sign-in screen beneath.

**Demonstrates:** the per-user `AppEnvironment` and the injection-container rebuild on sign-in and log out; persistent properties on the transient (no user) environment for the signed-in user and recent usernames; a coordinator that owns presentation.

## Places

A user's places are one list, stored in one Slate table:

- **Current location.** At most one row has `isCurrentLocation = true`. It always sorts first, can't be deleted or reordered, and is hidden entirely while location permission isn't granted. When the device's location changes meaningfully (more than about a kilometer), the places manager overwrites that row's coordinates and name, and its forecast is refetched. Its name comes from reverse geocoding on device through MapKit, because Open-Meteo has no reverse geocoding.
- **Saved places.** Rows the user added through search, in the user's own order.

Location permission is "When In Use", asked the first time the weather experience appears. Denying it simply means no current-location row.

**Demonstrates:** a Slate table with a flag column the manager treats specially; a manager driven by a CoreLocation stream; cross-manager reaction (the forecast manager observing the places list).

## The weather experience

The presented weather experience is a navigation stack with the **Places list** at its base and the **Place pager** above it.

- Launch, and every sign-in, opens the pager on the current location if there is one, otherwise on the first saved place.
- With no places at all, it lands on the Places list instead, showing its empty state.
- The pager's list button returns to the Places list. Tapping a row in the list opens the pager on that place.

### Place pager

Full-screen pages, one per place in list order, swiped horizontally. A bottom bar holds:

- **Center:** a page indicator, one dot per place, with a location arrow in place of the first dot when the current location is shown.
- **Trailing:** the list button, back to the Places list.

The pager is a UIKit container; each page is an ordinary Place Forecast screen built from its Builder. If places change while it is open (the current location appearing, say), pages are added or removed in place.

### Place Forecast

One place in full detail, as a vertically scrolling page:

- **Header.** A location arrow and "My Location" for the current location; the place name; the current temperature in large type; the condition; today's high and low.
- **Conditions.** A horizontal strip of the next 24 hours, with a control that switches what the strip shows between temperature (with condition icons), precipitation (probability and amount), and wind (speed and direction). The first column is "Now".
- **Next two hours.** 15-minute precipitation as a small bar chart, shown only when any precipitation is expected.
- **Daily.** The next 16 days: weekday ("Today" first), condition icon, precipitation probability when meaningful, and low and high on a range bar scaled across all the days shown, with a marker for the current temperature on today's bar.
- **Air quality.** The current AQI on the user's chosen scale with its category, the main pollutants (PM2.5, PM10, ozone), and the AQI for the next 24 hours. A place with no air-quality data hides the section.
- **Wind.** Current speed, gusts, and direction; today's maximum.
- **Precipitation.** Today's total and the next day with meaningful precipitation.
- **Details.** Feels like, humidity, pressure, UV index, visibility, sunrise and sunset.

### Places list

The base of the stack. A large "Weather" title, then one card per place, current location first. A card shows the place name, its local time (or "My Location" for the current location), the condition, the current temperature in large type, and today's high and low. Cards show cached data immediately and update in place when a refresh finishes; a card whose data is older than an hour says how old it is. Pull to refresh refetches every place.

A **search field** sits at the bottom of the screen, in both normal and edit modes.

The trailing toolbar button opens a **menu**:

- **Edit List**
- **Celsius** and **Fahrenheit**, with a checkmark on the current choice. These set the same temperature preference as the Units sheet.
- **Units**, which opens the Units sheet.
- **Log Out**

**Edit mode.** Edit List switches the list into edit mode: saved places get delete and reorder controls, and the current-location card stays fixed and uneditable at the top. Every delete and move is saved immediately. The toolbar button becomes a checkmark, which only leaves edit mode.

**Search.** Tapping the search field enters search mode, which replaces the list with results and shows a close button beside the field. Typing searches Open-Meteo's geocoding API after a short pause; each result shows its name, then region and country in a secondary color. Tapping a result adds it to the end of the list, closes search, and scrolls the list so the new card is visible. A result that is already saved is marked and can't be added twice. The close button leaves search without adding anything.

**Empty state.** With no places at all, the list shows a centered hero: an icon, a short headline, and a line asking the user to search for a place to add. It does not start search on its own; the user taps the search field.

**Demonstrates:** debounced input driving a `SerialTask`; in-memory results in a `MutableProperty`; live Slate writes and republishing; the same `PersistentProperty` changed from two places.

### Units sheet

Opened from the menu as a sheet, with a checkmark button that closes it.

- **Temperature:** Celsius, Fahrenheit, or Use System Setting (which shows what the system setting resolves to). The default is Use System Setting.
- **Other Units:** wind (km/h, m/s, mph, knots), precipitation (mm, in), pressure (hPa, inHg), and distance (km, mi), each a menu picker.
- **Display:** time format (system, 12-hour, 24-hour) and air quality scale (US, European).
- **Restore Defaults**, which returns every setting to its default for the device's region, with a footnote saying so.

Every setting takes effect everywhere immediately, with no refetch.

**Demonstrates:** one `PersistentProperty` per setting; derived display values with `Property(tracking:)`.

## Visual design

Flat, and built from typography, iconography, and color rather than imagery:

- No photographic or animated weather backgrounds. Each place's page and card take a flat color treatment chosen from its condition and whether it is day or night.
- Depth, where it's needed at all, comes from subtle shadows, soft or flat.
- Liquid Glass where the system uses it: toolbars, the pager's bottom bar, the search field, menus, and sheets. Standard UIKit and SwiftUI controls wherever they fit, such as toolbar items, menus, and pickers.
- SF Symbols for every icon, in their multicolor variants for weather conditions.
- Large, light numerals for temperatures, as the visual anchor of each page and card.

## Weather data

Data is always fetched in Open-Meteo's metric defaults (°C, km/h, mm, hPa) with `timezone=auto`, stored in those units, and converted for display. That is why changing a unit never refetches.

| Open-Meteo API | Data fetched |
|---|---|
| Forecast, `current` | temperature, apparent temperature, humidity, is day, weather code, precipitation, cloud cover, pressure, wind speed, direction, gusts |
| Forecast, `minutely_15` | precipitation (next 2 hours) |
| Forecast, `hourly` | temperature, apparent temperature, precipitation probability, precipitation, weather code, wind speed, direction, gusts, UV index, visibility, humidity, is day (48 hours) |
| Forecast, `daily` | weather code, temperature max and min, sunrise, sunset, UV index max, precipitation sum, precipitation hours, precipitation probability max, wind speed max, gusts max, dominant direction (16 days) |
| Air quality, `current` and `hourly` | US AQI, European AQI, PM2.5, PM10, ozone (24 hours) |
| Geocoding, `search` | Place search in the Places list |

The exact variable names are checked against Open-Meteo's documentation when the network resources are written.

### Freshness

- Weather for a place is cached in Slate and shown immediately at launch, even offline.
- A place's weather is refetched when it is older than 15 minutes and the app comes to the foreground, the Places list appears, or the place's page appears. Pull to refresh always refetches.
- Adding a place fetches its weather at once. Removing a place deletes its weather.
- A failed refresh leaves the cached data on screen and shows a small, dismissible error banner; a place with no cached data shows a retry state.

## Out of scope

- Real authentication, accounts, or sync between devices.
- Removing a user's data from the device.
- Widgets, notifications, severe-weather alerts, maps or radar, and issue reporting.
- Historical weather, marine, and other Open-Meteo APIs beyond the three above.
- iPad, landscape, and localization beyond English (strings still go through resources).
- Migrating saved places across schema changes; a schema change loses them (see the architecture doc).
