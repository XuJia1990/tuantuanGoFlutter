import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuantuan_go_flutter/src/core/constants/storage_keys.dart';
import 'package:tuantuan_go_flutter/src/core/storage/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps an unexpired access token', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.user: jsonEncode({
        'accessToken': 'valid-token',
        'userId': 7,
        'expiresTime': DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      }),
    });

    final storage = AppStorage();

    expect(await storage.getAccessToken(), 'valid-token');
    expect(await storage.getUserId(), '7');
  });

  test('clears cached auth when the access token is expired', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.user: jsonEncode({
        'accessToken': 'expired-token',
        'userId': 7,
        'expiresTime': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      }),
      StorageKeys.userDetail: '{"nickname":"cached"}',
      StorageKeys.userAvatar: 'avatar.png',
      StorageKeys.isGroupManager: true,
    });

    final storage = AppStorage();

    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getUserId(), isNull);
    expect(await storage.getUserDetail(), isNull);
    expect(await storage.getUserAvatar(), isNull);
    expect(await storage.isGroupManager(), isFalse);
  });
}
