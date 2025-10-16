/// Application-wide constants
class AppConstants {
  // Private constructor
  AppConstants._();

  // App Metadata
  static const String appName = 'Thothcraft';
  static const String appVersion = '1.0.0';
  
  // Bundle IDs
  static const String bundleIdProd = 'com.thothcraft.app';
  static const String bundleIdDev = 'com.thothcraft.app.dev';
  
  // External URLs
  static const String portalUrl = 'https://portal-three-rho.vercel.app';
  static const String frontendUrl = 'https://thothfrontend.vercel.app';
  static const String githubUrl = 'https://github.com/thothcraft';
  
  // Video URLs (Remote streaming)
  static const String heroVideoBgUrl = 'https://example.com/videos/hero_video_bg.mp4';
  static const String gettingStartedVideoUrl = 'https://example.com/videos/getting_started.mp4';
  static const String firstProjectVideoUrl = 'https://example.com/videos/first.mp4';
  static const String sensorsVideoUrl = 'https://example.com/videos/sensors.mp4';
  
  // 3D Model URL (for future WebView implementation)
  static const String model3dUrl = 'https://poly.cam/capture/ABE69FEA-A1DF-4CC5-BC65-CF1DB40BFEE8/embed';
  
  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  
  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 18.0;
  static const double radiusXl = 24.0;
  
  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  
  // Max Content Width
  static const double maxContentWidth = 1200;
  
  // Sensor Types
  static const List<String> sensorTypes = [
    'Temperature',
    'Humidity',
    'Pressure',
    'Accelerometer',
    'Gyroscope',
    'Magnetometer',
    'Camera',
  ];
  
  // Kit Pricing
  static const Map<String, double> kitPrices = {
    'starter': 99.0,
    'pro': 149.0,
    'classroom': 499.0,
  };
  
  // Plan Pricing
  static const Map<String, String> planPrices = {
    'free': '\$0/mo',
    'paid': '\$9.99/mo',
    'organization': 'Custom',
  };
}
