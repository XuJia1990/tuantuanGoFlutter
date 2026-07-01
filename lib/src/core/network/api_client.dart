import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../storage/app_storage.dart';
import 'api_config.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(appStorageProvider));
});

class ApiClient {
  ApiClient({required AppStorage storage}) : _storage = storage {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.uatBaseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: const {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json',
          'Content-Type': 'application/json;charset=UTF-8',
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.extra[_requestStartKey] = DateTime.now();
          await _applyCommonHeaders(options);
          _logRequest(options);
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logResponse(response);
          handler.next(response);
        },
        onError: (error, handler) {
          _logError(error);
          handler.next(error);
        },
      ),
    );
  }

  static const _requestStartKey = 'requestStart';

  final AppStorage _storage;
  final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  late final Dio _dio;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
    );
    return response.data;
  }

  Future<dynamic> post(String path, {Object? data}) async {
    final response = await _dio.post<dynamic>(path, data: data);
    return response.data;
  }

  Future<dynamic> put(String path, {Object? data}) async {
    final response = await _dio.put<dynamic>(path, data: data);
    return response.data;
  }

  Future<dynamic> delete(String path, {Object? data}) async {
    final response = await _dio.delete<dynamic>(path, data: data);
    return response.data;
  }

  Future<void> _applyCommonHeaders(RequestOptions options) async {
    final token = await _storage.getAccessToken();
    final userId = await _storage.getUserId();
    final deviceId = await _storage.getDeviceId();
    final packageInfo = await _packageInfo;

    final requestLongitude = _headerString(options.headers, 'longitude');
    final requestLatitude = _headerString(options.headers, 'latitude');
    if (requestLongitude != null && requestLatitude != null) {
      await _storage.saveLocation(
        longitude: requestLongitude,
        latitude: requestLatitude,
      );
    }
    final longitude = requestLongitude ?? await _storage.getLongitude();
    final latitude = requestLatitude ?? await _storage.getLatitude();

    options.headers.remove('Authorization');
    options.headers
      ..['authorization'] = token ?? ''
      ..['deviceid'] = deviceId
      ..['os'] = _osName
      ..['appversion'] = packageInfo.version
      ..['channelid'] = _channelId
      ..['osversion'] = Platform.operatingSystemVersion
      ..['longitude'] = longitude ?? ''
      ..['latitude'] = latitude ?? ''
      ..['userId'] = userId ?? '';
  }

  String? _headerString(Map<String, dynamic> headers, String key) {
    final value = headers[key];
    if (value == null) return null;
    final stringValue = value.toString();
    return stringValue.isEmpty ? null : stringValue;
  }

  String get _osName {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return Platform.operatingSystem;
  }

  String get _channelId {
    if (Platform.isIOS) return 'ios_jp_tuantuan';
    if (Platform.isAndroid) return 'android_jp_tuantuan';
    return '${Platform.operatingSystem}_jp_tuantuan';
  }

  void _logRequest(RequestOptions options) {
    _logJson({
      'type': 'request',
      'method': options.method,
      'url': options.uri.toString(),
      'query': options.queryParameters,
      'body': options.data,
      'headers': _safeHeaders(options.headers),
    });
  }

  void _logResponse(Response<dynamic> response) {
    _logJson({
      'type': 'response',
      'method': response.requestOptions.method,
      'url': response.requestOptions.uri.toString(),
      'statusCode': response.statusCode,
      'durationMs': _elapsed(response.requestOptions),
      'data': response.data,
    });
  }

  void _logError(DioException error) {
    _logJson(
      {
        'type': 'error',
        'method': error.requestOptions.method,
        'url': error.requestOptions.uri.toString(),
        'statusCode': error.response?.statusCode,
        'durationMs': _elapsed(error.requestOptions),
        'message': error.message,
        'data': error.response?.data,
      },
      name: 'ApiClient',
      error: error,
      stackTrace: error.stackTrace,
    );
  }

  int _elapsed(RequestOptions options) {
    final start = options.extra[_requestStartKey];
    if (start is! DateTime) return 0;
    return DateTime.now().difference(start).inMilliseconds;
  }

  Map<String, dynamic> _safeHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      final lowerKey = key.toLowerCase();
      if (lowerKey == 'authorization') return MapEntry(key, '***');
      return MapEntry(key, value);
    });
  }

  void _logJson(
    Map<String, dynamic> data, {
    String name = 'ApiClient',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      const JsonEncoder.withIndent('  ').convert(_jsonSafe(data)),
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  dynamic _jsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList();
    }
    return value.toString();
  }
}
