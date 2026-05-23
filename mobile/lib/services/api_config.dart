/// API environment configuration
class ApiConfig {
  static const String _dev = 'http://127.0.0.1:8000';
  static const String _prod = 'http://8.160.174.178:8000';

  // Set to false for production
  static const bool _useDev = false;

  static String get baseUrl => _useDev ? _dev : _prod;
}
