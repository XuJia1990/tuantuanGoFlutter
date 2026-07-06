import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

final appStorageProvider = Provider<AppStorage>((ref) => AppStorage());

class AuthRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final authRevisionProvider = NotifierProvider<AuthRevision, int>(
  AuthRevision.new,
);

final isGroupManagerProvider = FutureProvider<bool>((ref) async {
  ref.watch(authRevisionProvider);
  return ref.watch(appStorageProvider).isGroupManager();
});

class AppStorage {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> getAccessToken() async {
    final rawUser = (await _prefs).getString(StorageKeys.user);
    if (rawUser == null || rawUser.isEmpty) return null;
    final match = RegExp(r'"accessToken"\s*:\s*"([^"]+)"').firstMatch(rawUser);
    return match?.group(1);
  }

  Future<String?> getUserId() async {
    final rawUser = (await _prefs).getString(StorageKeys.user);
    if (rawUser == null || rawUser.isEmpty) return null;
    final match = RegExp(r'"userId"\s*:\s*"?([^",}]+)"?').firstMatch(rawUser);
    return match?.group(1);
  }

  Future<void> saveUser(String value) async {
    await (await _prefs).setString(StorageKeys.user, value);
  }

  Future<String?> getUserDetail() async {
    return (await _prefs).getString(StorageKeys.userDetail);
  }

  Future<void> saveUserDetail(String value) async {
    await (await _prefs).setString(StorageKeys.userDetail, value);
  }

  Future<String?> getUserAvatar() async {
    return (await _prefs).getString(StorageKeys.userAvatar);
  }

  Future<void> saveUserAvatar(String value) async {
    await (await _prefs).setString(StorageKeys.userAvatar, value);
  }

  Future<bool> isSignedIn() async => (await getAccessToken()) != null;

  Future<bool> isGroupManager() async {
    return (await _prefs).getBool(StorageKeys.isGroupManager) ?? false;
  }

  Future<void> saveIsGroupManager(bool value) async {
    await (await _prefs).setBool(StorageKeys.isGroupManager, value);
  }

  Future<String> getDeviceId() async {
    final prefs = await _prefs;
    final deviceId = prefs.getString(StorageKeys.deviceId);
    if (deviceId != null && deviceId.isNotEmpty) return deviceId;
    final generated = _generateDeviceId();
    await prefs.setString(StorageKeys.deviceId, generated);
    return generated;
  }

  Future<void> saveLocation({
    required String longitude,
    required String latitude,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(StorageKeys.longitude, longitude);
    await prefs.setString(StorageKeys.latitude, latitude);
  }

  Future<String?> getLongitude() async {
    return (await _prefs).getString(StorageKeys.longitude);
  }

  Future<String?> getLatitude() async {
    return (await _prefs).getString(StorageKeys.latitude);
  }

  Future<void> clearAuth() async {
    final prefs = await _prefs;
    await prefs.remove(StorageKeys.user);
    await prefs.remove(StorageKeys.userDetail);
    await prefs.remove(StorageKeys.userAvatar);
    await prefs.remove(StorageKeys.isGroupManager);
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return [
      value.substring(0, 8),
      value.substring(8, 12),
      value.substring(12, 16),
      value.substring(16, 20),
      value.substring(20),
    ].join('-');
  }
}
