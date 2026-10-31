import 'dart:io';

class Env {
  static String get mongoUri =>
      _get('MONGODB_URI', 'mongodb://localhost:27017');
  static String get databaseName => _get('MONGODB_DATABASE', 'ecommerce_api');
  static String get jwtSecret => _get('JWT_SECRET');
  static String get jwtIssuer => _get('JWT_ISSUER', 'ecommerce-api');
  static String get abaMerchantId => _get('ABA_PAYWAY_MERCHANT_ID');
  static String get abaHmacKey =>
      _getFirst(['ABA_PAYWAY_HMAC_KEY', 'ABA_PAYWAY_API_KEY']);
  static String get abaBaseUrl =>
      _get('ABA_PAYWAY_BASE_URL', 'https://checkout-sandbox.payway.com.kh');
  static String get abaPurchaseUrl => _getFirst(
        ['ABA_PAYWAY_PURCHASE_URL', 'ABA_PAYWAY_API_URL'],
        '${abaBaseUrl.replaceFirst(RegExp(r'/$'), '')}'
        '/api/payment-gateway/v1/payments/purchase',
      );
  static String get abaCheckTransactionUrl => _get(
        'ABA_PAYWAY_CHECK_TRANSACTION_URL',
        '${abaBaseUrl.replaceFirst(RegExp(r'/$'), '')}'
            '/api/payment-gateway/v1/payments/check-transaction-2',
      );
  static String get publicApiBaseUrl =>
      _get('PUBLIC_API_BASE_URL', 'http://localhost:8080');
  static Set<String> get corsAllowedOrigins => _get(
        'CORS_ALLOWED_ORIGINS',
        'http://localhost,http://127.0.0.1',
      )
          .split(',')
          .map((origin) => origin.trim())
          .where((origin) => origin.isNotEmpty)
          .toSet();
  static String get successUrl =>
      _get('FRONTEND_SUCCESS_URL', 'http://localhost:3000/payment/success');
  static String get cancelUrl =>
      _get('FRONTEND_CANCEL_URL', 'http://localhost:3000/payment/cancel');
  static String _get(String key, [String? fallback]) {
    final value = _configuredValue(key);
    if (value != null && value.isNotEmpty) return value;
    if (fallback != null) return fallback;
    throw StateError('Missing required environment variable: $key');
  }

  static String _getFirst(List<String> keys, [String? fallback]) {
    for (final key in keys) {
      final value = _configuredValue(key);
      if (value != null && value.isNotEmpty) return value;
    }
    if (fallback != null) return fallback;
    throw StateError('Missing required environment variable: ${keys.first}');
  }

  static String? _configuredValue(String key) {
    final value = Platform.environment[key];
    if (value != null && value.isNotEmpty) return value;
    return _localEnvValue(key);
  }

  static String? _localEnvValue(String key) {
    final envFile = File('.env');
    if (!envFile.existsSync()) return null;

    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separator = trimmed.indexOf('=');
      if (separator < 0 || trimmed.substring(0, separator).trim() != key) {
        continue;
      }
      var value = trimmed.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      return value;
    }
    return null;
  }
}
