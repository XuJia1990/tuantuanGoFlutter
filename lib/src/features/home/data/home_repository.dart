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

  Future<List<Station>> getCouponStations({
    required double longitude,
    required double latitude,
  }) async {
    final raw = await _client.get(
      TuanTuanEndpoints.stationListCoupon,
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
      throw HomeApiException(envelope.message ?? '优惠车站获取失败');
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

  Future<ShopDetail> getShopDetail(String shopId) async {
    final raw = await _client.get(
      TuanTuanEndpoints.shopInfo,
      query: {'shopId': shopId},
    );
    final envelope = ApiEnvelope.parse<ShopDetail>(
      raw,
      (data) => data is Map
          ? ShopDetail.fromJson(Map<String, dynamic>.from(data))
          : ShopDetail.fromJson(const {}),
    );
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '店铺详情获取失败');
    }
    return envelope.data ?? ShopDetail.fromJson(const {});
  }

  Future<PagedResult<CouponSummary>> getCouponPage({
    required int pageNo,
    int pageSize = 10,
    required String shopId,
  }) async {
    final raw = await _client.get(
      TuanTuanEndpoints.couponPage,
      query: {'pageNo': pageNo, 'pageSize': pageSize, 'shopId': shopId},
    );
    final envelope = ApiEnvelope.parse<PagedResult<CouponSummary>>(
      raw,
      (data) => PagedResult.parse(data, CouponSummary.fromJson),
    );
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '团优惠获取失败');
    }
    return envelope.data ?? const PagedResult(list: [], total: 0);
  }

  Future<PagedResult<CouponMain>> getCouponPageMain({
    required int pageNo,
    int pageSize = 10,
    required String stationId,
  }) async {
    final raw = await _client.get(
      TuanTuanEndpoints.couponPageMain,
      query: {'pageNo': pageNo, 'pageSize': pageSize, 'stationId': stationId},
    );
    final envelope = ApiEnvelope.parse<PagedResult<CouponMain>>(
      raw,
      (data) => PagedResult.parse(data, CouponMain.fromJson),
    );
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '团优惠获取失败');
    }
    return envelope.data ?? const PagedResult(list: [], total: 0);
  }

  Future<CouponDetail> getCouponInfo({required String couponId}) async {
    final raw = await _client.get(
      TuanTuanEndpoints.couponInfo,
      query: {'couponId': couponId},
    );
    final envelope = ApiEnvelope.parse<CouponDetail>(
      raw,
      (data) => CouponDetail.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '团优惠详情获取失败');
    }
    return envelope.data ?? CouponDetail.fromJson(const {});
  }

  Future<void> addShopFav({
    required String userId,
    required String shopId,
  }) async {
    final raw = await _client.get(
      TuanTuanEndpoints.insertShopFav,
      query: {'userId': userId, 'shopId': shopId},
    );
    final envelope = ApiEnvelope.parse<void>(raw, (_) {});
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '收藏失败');
    }
  }

  Future<void> deleteShopFav({
    required String userId,
    required String shopId,
  }) async {
    final raw = await _client.get(
      TuanTuanEndpoints.deleteShopFav,
      query: {'userId': userId, 'shopId': shopId},
    );
    final envelope = ApiEnvelope.parse<void>(raw, (_) {});
    if (!envelope.isSuccess) {
      throw HomeApiException(envelope.message ?? '取消收藏失败');
    }
  }
}

class HomeApiException implements Exception {
  const HomeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
