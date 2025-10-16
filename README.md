# Thothcraft Mobile App

Revolutionary AI/IoT platform mobile application built with Flutter. Features federated learning, differential privacy, and smart sensor integration for Raspberry Pi-powered Thoth devices.

## 📱 About

Thothcraft is a mobile companion app for the Thoth IoT platform, enabling students, researchers, and makers to:
- Monitor and control Thoth devices remotely
- Participate in federated learning experiments
- Explore demos and tutorials
- Access privacy-preserving AI/IoT tools

## 🏗️ Architecture

### Stack
- **Framework**: Flutter 3.27+ / Dart 3.6+
- **State Management**: Riverpod 2.x
- **Routing**: go_router 14.x
- **HTTP Client**: dio
- **Video Playback**: video_player + chewie
- **Local Storage**: shared_preferences

### Project Structure
```
lib/
├── app.dart                 # Main app widget
├── main.dart                # Entry point
├── core/                    # Core utilities
│   ├── theme/               # App theming
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_theme.dart
│   ├── constants/           # Constants
│   └── utils/               # Helper functions
├── features/                # Feature modules
│   ├── home/                # Landing page
│   ├── platform/            # FL/DP platform
│   ├── devices/             # Device management
│   ├── demos/               # Video demos
│   ├── research/            # Publications
│   ├── contact/             # Contact form
│   ├── settings/            # App settings
│   └── legal/               # Privacy & Terms
├── routes/                  # Navigation
│   └── app_router.dart
└── shared/                  # Shared widgets
    └── widgets/
```

## 🚀 Getting Started

### Prerequisites
- Flutter 3.27.0 or higher
- Dart 3.6.0 or higher
- Android Studio / Xcode for device testing
- VS Code (optional) with Flutter extension

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Thothcraft/thoth-app.git
   cd thoth-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run code generation (if needed)**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   # Development
   flutter run

   # Release mode
   flutter run --release

   # Specific device
   flutter run -d <device-id>
   ```

### Build for Production

**Android (APK)**
```bash
flutter build apk --release
```

**Android (App Bundle)**
```bash
flutter build appbundle --release
```

**iOS**
```bash
flutter build ios --release
```

## 🧪 Testing

### Run all tests
```bash
flutter test
```

### Run with coverage
```bash
flutter test --coverage
```

### Widget tests only
```bash
flutter test test/widget_tests
```

### Unit tests only
```bash
flutter test test/unit_tests
```

## 🎨 Theming

The app uses an Apple-inspired design system with:
- **Primary Color**: `#0071E3` (Blue)
- **Background**: `#FBFBFD` (Off-white)
- **Typography**: SF Pro Display style
- **Glass Morphism**: Frosted glass effects throughout

### Dark Mode
Dark mode is fully supported and respects system preferences.

## 📐 Screen Map

| Route | Screen | Description |
|-------|--------|-------------|
| `/` | Home | Hero, value props, merged About |
| `/platform` | Platform | FL, DP, Secure Aggregation |
| `/devices` | Devices | IoT device hub |
| `/devices/har` | HAR Device | Human Activity Recognition |
| `/devices/wifi` | WiFi Device | WiFi sensing |
| `/devices/env` | Env Device | Environmental monitoring |
| `/demos` | Demos | Video gallery |
| `/research` | Research | Publications & press |
| `/contact` | Contact | Contact form |
| `/settings` | Settings | App preferences |
| `/legal` | Legal | Privacy & Terms |

## 🔧 Configuration

### Environment Variables
Configure using `--dart-define` flags:

```bash
flutter run \
  --dart-define=PORTAL_URL=https://your-portal.com \
  --dart-define=API_BASE_URL=https://api.your-domain.com
```

### Bundle IDs
- **Production**: `com.thothcraft.app`
- **Development**: `com.thothcraft.app.dev`

## 📦 Assets

### Images
Place images in:
- `assets/images/` - General images
- `assets/images/products/` - Product photos
- `assets/images/icons/` - Icon GIFs/images

### Videos
Videos are streamed remotely (not bundled). Update URLs in `lib/core/constants/app_constants.dart`.

## 🔗 Deep Linking

The app supports deep links for external portal integration:
- Scheme: `thothcraft://`
- Example: `thothcraft://devices/har`

## 🌐 Localization

Currently supports English (US). To add languages:

1. Add locale to `supportedLocales` in `app.dart`
2. Create `.arb` files in `lib/l10n/`
3. Run `flutter gen-l10n`

## 📊 State Management

Uses Riverpod for state management. Key providers:
- `themeProvider` - Theme mode (light/dark/system)
- `videoAutoplayProvider` - Video autoplay preference
- `contactFormProvider` - Contact form state

## 🐛 Debugging

### Enable verbose logging
```bash
flutter run -v
```

### Debug layout issues
Enable debug paint in settings screen or use:
```bash
flutter run --debug --dart-define=DEBUG_LAYOUT=true
```

## 🚢 Deployment

### Android
1. Update `android/app/build.gradle` with signing config
2. Generate keystore: `keytool -genkey -v -keystore ~/thothcraft.jks ...`
3. Build: `flutter build appbundle --release`
4. Upload to Google Play Console

### iOS
1. Configure signing in Xcode
2. Update bundle ID in `ios/Runner.xcodeproj`
3. Build: `flutter build ios --release`
4. Archive and upload via Xcode

## 🤝 Contributing

See main project repository for contribution guidelines.

## 📄 License

See `LICENSE` file in root directory.

## 🔗 Links

- **Portal**: https://portal-three-rho.vercel.app
- **Frontend**: https://thothfrontend.vercel.app
- **GitHub**: https://github.com/thothcraft

## 📞 Support

For questions or issues:
- Contact form in app
- GitHub Issues
- Email: support@thothcraft.com

---

**Built with ❤️ by the Thothcraft team**
