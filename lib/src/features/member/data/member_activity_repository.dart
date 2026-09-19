import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import 'member_activity_models.dart';

final memberActivityRepositoryProvider = Provider<MemberActivityRepository>(
  (ref) => MemberActivityRepository(ref.watch(apiClientProvider)),
);

class MemberActivityRepository {
  const MemberActivityRepository(this._client);

  final ApiClient _client;

  Future<List<MemberActivitySummary>> listByShop(String shopId) async {
    final raw = await _client.get(
      TuanTuanEndpoints.activityList,
      query: {'shopId': shopId},
    );
    return _unwrap<List<MemberActivitySummary>>(raw, (data) {
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (item) =>
                MemberActivitySummary.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    });
  }

  Future<MemberActivityDetail> getDetail(String activityId) async {
    final raw = await _client.get(TuanTuanEndpoints.activityDetail(activityId));
    return _unwrap<MemberActivityDetail>(
      raw,
      (data) =>
          MemberActivityDetail.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<MemberActivityDetail> submitStamp({
    required String activityId,
    required String shopId,
    required bool stampSuccess,
    required String requestId,
  }) async {
    final raw = await _client.post(
      TuanTuanEndpoints.activityStamp(activityId),
      data: {
        'shopId': int.tryParse(shopId) ?? shopId,
        'stampSuccess': stampSuccess,
        'requestId': requestId,
      },
    );
    return _unwrap<MemberActivityDetail>(
      raw,
      (data) =>
          MemberActivityDetail.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<ActivityRewardClaimResult> claimReward({
    required String activityId,
    required String rewardId,
    required String requestId,
  }) async {
    final raw = await _client.post(
      TuanTuanEndpoints.activityRewardClaim(activityId, rewardId),
      data: {'requestId': requestId},
    );
    return _unwrap<ActivityRewardClaimResult>(
      raw,
      (data) => ActivityRewardClaimResult.fromJson(
        Map<String, dynamic>.from(data as Map),
      ),
    );
  }
}

class MemberActivityApiException implements Exception {
  const MemberActivityApiException(this.code, this.message);

  final int? code;
  final String message;

  bool get requiresLogin => code == 401 || code == 2010001019;

  @override
  String toString() => message;
}

T _unwrap<T>(dynamic raw, T Function(dynamic data) parseData) {
  if (raw is! Map) {
    throw const MemberActivityApiException(null, '响应格式错误');
  }
  final code = _asNullableInt(raw['code']);
  final message = raw['msg']?.toString() ?? raw['message']?.toString() ?? '';
  if (code != 200) {
    throw MemberActivityApiException(code, message.isEmpty ? '请求失败' : message);
  }
  try {
    return parseData(raw['data']);
  } catch (_) {
    throw const MemberActivityApiException(null, '活动数据格式错误');
  }
}

int? _asNullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String newActivityRequestId(String prefix) {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}-${hex.substring(0, 16)}';
}
