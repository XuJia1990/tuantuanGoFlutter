import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

final appStorageProvider = Provider<AppStorage>((ref) => AppStorage());

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

  Future<bool> isSignedIn() async => (await getAccessToken()) != null;

  Future<bool> isGroupManager() async {
    return (await _prefs).getBool(StorageKeys.isGroupManager) ?? false;
  }

  Future<void> clearAuth() async {
    final prefs = await _prefs;
    await prefs.remove(StorageKeys.user);
    await prefs.remove(StorageKeys.userDetail);
    await prefs.remove(StorageKeys.userAvatar);
    await prefs.remove(StorageKeys.isGroupManager);
  }
}
