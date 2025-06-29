class AppConfig {
  // Production URLs
  static const String productionBaseUrl =
      "https://cogniteamai-server-16839756830.us-central1.run.app/api/v1";
  static const String productionWebSocketUrl =
      "wss://cogniteamai-server-16839756830.us-central1.run.app";

  // Development URLs
  static const String developmentBaseUrl = "http://localhost:8000/api/v1";
  static const String developmentWebSocketUrl = "ws://localhost:8000";

  // Get the appropriate base URL based on environment
  static String get backendBaseUrl {
    // Check if we're in production (Firebase hosting)
    const bool isProduction = bool.fromEnvironment('dart.vm.product');

    if (isProduction) {
      return productionBaseUrl;
    } else {
      return developmentBaseUrl;
    }
  }

  static String get backendWebSocketUrl {
    const bool isProduction = bool.fromEnvironment('dart.vm.product');

    if (isProduction) {
      return productionWebSocketUrl;
    } else {
      return developmentWebSocketUrl;
    }
  }

  static bool get isProduction {
    return const bool.fromEnvironment('dart.vm.product');
  }
}
