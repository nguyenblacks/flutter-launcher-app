# swavoti (go launcher 7) - installation guide

## prerequisites

before you begin, ensure you have the following installed on your system:

- **flutter sdk** (version 3.0 or higher) - [download from flutter.dev](https://flutter.dev/docs/get-started/install)
- **dart sdk** (comes bundled with flutter)
- **android studio** (for android development) or **xcode** (for ios development)
- **git** (for cloning the repository)
- a physical device or emulator/simulator for testing

## step 1: clone the repository

open your terminal and run:

```bash
git clone https://github.com/yourusername/swavoti.git
cd swavoti
```

if you have the project files locally, navigate to the project directory:

```bash
cd /path/to/swavoti
```

## step 2: install dependencies

run the following command to fetch all required packages:

```bash
flutter pub get
```

this will download all dependencies listed in the `pubspec.yaml` file.

## step 3: verify flutter setup

run this command to check that everything is configured correctly:

```bash
flutter doctor
```

ensure there are no critical issues. if you see warnings about missing android licenses, run:

```bash
flutter doctor --android-licenses
```

## step 4: build the app

### for android

```bash
flutter build apk --debug
```

or for a release build:

```bash
flutter build apk --release
```

the apk file will be generated in `build/app/outputs/flutter-apk/`.

### for ios (macos only)

```bash
flutter build ios --debug
```

or for release:

```bash
flutter build ios --release
```

## step 5: run the app

### on an emulator/simulator

first, start your emulator or simulator, then run:

```bash
flutter run
```

### on a physical device

1. enable developer mode and usb debugging on your device
2. connect your device via usb
3. verify the device is detected:

```bash
flutter devices
```

4. run the app:

```bash
flutter run -d <device-id>
```

### on chrome (web preview)

```bash
flutter run -d chrome
```

## what to expect

when the app launches successfully, you should see:

- a **home screen** with a grid of app icons
- a **dock** at the bottom with frequently used apps
- a **search bar** at the top for finding apps
- a **settings panel** accessible via a swipe or button
- smooth animations when opening/closing apps
- a **widget** area where you can add custom widgets

the app is designed to be a lightweight, fast launcher alternative for android devices. the main ui elements are:

- **app drawer** - swipe up to access all installed apps
- **home screen** - shows your favorite apps and widgets
- **dock** - quick access to your most-used apps
- **search bar** - type to filter and find apps instantly
- **settings menu** - customize themes, icon sizes, and gestures

## troubleshooting

### common issues

**issue: `flutter: command not found`**
- ensure flutter is added to your system path
- restart your terminal after installation

**issue: build fails with gradle errors**
- run `flutter clean` and then `flutter pub get` again
- check your android sdk path in `android/local.properties`

**issue: app crashes on launch**
- check the device logs with `flutter logs`
- ensure you have the latest flutter version

**issue: icons not loading**
- clear the app cache from device settings
- restart the app

## additional notes

- the app requires **android 5.0 (api 21)** or higher
- for ios, it requires **ios 11.0** or higher
- the app is optimized for **portrait mode** but works in landscape
- default theme is dark mode with accent colors

## uninstalling

to remove the app from your device:

- **android**: go to settings > apps > swavoti > uninstall
- **ios**: long-press the app icon > remove app
- **emulator**: use `adb uninstall com.example.swavoti`

## support

if you encounter any issues not covered here, please:

1. check the [github issues page](https://github.com/yourusername/swavoti/issues)
2. run `flutter doctor -v` and include the output in your report
3. provide your device model and os version

---

enjoy using swavoti! it's designed to be fast, minimal, and customizable.