# WeatherShmeather

An iOS app architecture example: a small weather app built on [Open-Meteo](https://open-meteo.com/), using Velocity, Inject, SwiftAsyncEx, SwiftUIEx, and Slate.

- [Product spec](docs/PRODUCT.md)
- [iOS architecture](docs/engineering/IOS-ARCHITECTURE.md)

## Getting started

Requires Xcode with the iOS 26 SDK and Homebrew.

```bash
make bootstrap
```

This installs Mint and the pinned tools, sets up the git hooks, pulls dependencies, and generates `WeatherShmeather.xcodeproj`. After that, run `make` after every pull or branch switch, and `make modules && make project` after adding or removing a module.
