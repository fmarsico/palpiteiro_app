import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_defaultApiBaseUrl.isNotEmpty) {
      return _defaultApiBaseUrl;
    }

    // Android emulator needs 10.0.2.2 to reach the host machine localhost.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
  }
}
