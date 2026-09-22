# Thothcraft Mobile App

AI/IoT platform mobile app built with Flutter. Features federated learning, differential privacy, and smart sensor integration for Raspberry Pi-powered Thoth devices.

## 📱 About

Mobile companion app for the Thoth IoT platform enabling device monitoring, federated learning experiments, and privacy-preserving AI/IoT tools.

## 🚀 Quick Start

### Prerequisites
- Flutter 3.27+ / Dart 3.6+
- Android Studio or Xcode (for device testing)

### Installation

```bash
git clone https://github.com/Thothcraft/thoth-app.git
cd thoth-app
flutter pub get
flutter run
```

### Build for Production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## �️ Tech Stack

- **Framework**: Flutter 3.27+ / Dart 3.6+
- **State Management**: Riverpod 2.x
- **Routing**: go_router 14.x
- **HTTP**: dio
- **Video**: video_player + chewie

## 📐 Key Features

- Monitor and control Thoth devices remotely
- Participate in federated learning experiments
- Video demos and tutorials
- Privacy-preserving AI/IoT tools
- Apple-inspired glass morphism design
- Dark mode support

---


## Debug APK for phone testing

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=BRAIN_URL=https://web-production-d7d37.up.railway.app
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. Sideload this debug-signed
APK on Android. Release distribution requires your signing keystore. The default
API remains `https://api.thothcraft.com`; BRAIN_URL changes the client's initial
URL. An already-saved URL in app settings takes precedence. CI uploads the debug
APK as `thothcraft-debug-apk`.
