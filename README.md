# Daily Dose of Play app

The iPhone and Android app for [Daily Dose of Play](https://www.dailydoseofplay.com):
free two-player games, no sign-up. The app is a thin Flutter shell that shows
the website in a WebView. The games live in the website's repository,
[Faezehyas/dailydoseofplay](https://github.com/Faezehyas/dailydoseofplay); read
[ARCHITECTURE.md](ARCHITECTURE.md) for what the shell does and what it leaves
to the site.

Bundle ID and Android package: `com.dailydoseofplay.app`. Supported: iOS 15+
and Android 8+ (API 26).

## Set up

- [Flutter](https://docs.flutter.dev/get-started/install) stable, with Xcode
  for iOS and the Android SDK for Android. `flutter doctor` lists what's
  missing.
- `flutter pub get`

## Run

```sh
flutter devices                 # pick a simulator or emulator
flutter run -d "iPhone 17 Pro"  # the live site, in debug mode
```

The app needs the network: it loads https://www.dailydoseofplay.com.

## Test

```sh
flutter analyze
flutter test                                  # widget tests, no device needed
flutter test integration_test -d "iPhone 17 Pro"
```

The integration test runs the real WebView against the live site, so it needs
a simulator, emulator or phone and the network. It checks that the site loads
and that the site's bridge reaches the app.

## Build

```sh
flutter build ios --simulator --debug  # iOS, for the simulator, unsigned
flutter build apk --debug              # Android
```

Release builds need signing, which stays out of this repository: no
certificates, provisioning profiles, keystores or `google-services` files.
