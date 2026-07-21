class ApiConfig {
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'uat');
  static const productionBaseUrl = 'https://api.tuantuan-go.com';
  static const uatBaseUrl = 'https://api-uat.tuantuan-go.com';
  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 10);

  static bool get isProduction => appEnv == 'prod' || appEnv == 'production';
  static String get baseUrl => isProduction ? productionBaseUrl : uatBaseUrl;
}
