import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import 'home_models.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

class HomeRepository {
  const HomeRepository(this._client);

  final ApiClient _client;

  Future<List<Station>> getStations({
    required double longitude,
    required double latitude,
  }) async {
    final raw = await _client.get(
      TuanTuanEndpoints.stationList,
      query: {'longitude': longitude, 'latitude': latitude},
      headers: {'longitude': longitude, 'latitude': latitude},
    );
    final envelope = ApiEnvelope.parse<List<Station>>(
      raw,
      (data) => data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) => Station.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '车站获取失败');
    }
    return envelope.data ?? const [];
  }

  Future<List<HomeCategory>> getCategories(int type) async {
    final raw = await _client.get(
      TuanTuanEndpoints.category,
      query: {'type': type},
    );
    final envelope = ApiEnvelope.parse<List<HomeCategory>>(
      raw,
      (data) => data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) =>
                      HomeCategory.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '分类获取失败');
    }
    return envelope.data ?? const [];
  }

  Future<PagedResult<ShopSummary>> getShopList({
    required int pageNo,
    int pageSize = 10,
    required String stationId,
    required String sortCondition,
    required String typeCondition,
  }) async {
    final raw = await _client.get(
      TuanTuanEndpoints.shopListMain,
      query: {
        'pageNo': pageNo,
        'pageSize': pageSize,
        'stationId': stationId,
        'sortCondition': sortCondition,
        'typeCondition': typeCondition,
      },
    );
    final envelope = ApiEnvelope.parse<PagedResult<ShopSummary>>(
      raw,
      (data) => PagedResult.parse(data, ShopSummary.fromJson),
    );
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '店铺获取失败');
    }
    return envelope.data ?? const PagedResult(list: [], total: 0);
  }

  Future<PagedResult<ShopSummary>> searchShops({
    required int pageNo,
    int pageSize = 10,
    required String keyword,
  }) async {
    final raw = await _client.get(
      TuanTuanEndpoints.search,
      query: {'pageNo': pageNo, 'pageSize': pageSize, 'keyword': keyword},
    );
    final envelope = ApiEnvelope.parse<PagedResult<ShopSummary>>(
      raw,
      (data) => PagedResult.parse(data, ShopSummary.fromJson),
    );
    if (!envelope.isSuccess) throw HomeApiException(envelope.message ?? '搜索失败');
    return envelope.data ?? const PagedResult(list: [], total: 0);
  }
}

class HomeApiException implements Exception {
  const HomeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
