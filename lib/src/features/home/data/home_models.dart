class ApiEnvelope<T> {
  const ApiEnvelope({required this.code, this.message, this.data});

  final int? code;
  final String? message;
  final T? data;

  bool get isSuccess => code == 200;

  static ApiEnvelope<T> parse<T>(
    dynamic raw,
    T Function(dynamic raw) parseData,
  ) {
    if (raw is! Map) return const ApiEnvelope(code: null, message: '响应格式错误');
    return ApiEnvelope<T>(
      code: _asInt(raw['code']),
      message: raw['msg']?.toString() ?? raw['message']?.toString(),
      data: raw.containsKey('data') ? parseData(raw['data']) : null,
    );
  }
}

class PagedResult<T> {
  const PagedResult({required this.list, required this.total});

  final List<T> list;
  final int total;

  static PagedResult<T> parse<T>(
    dynamic raw,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (raw is! Map) return const PagedResult(list: [], total: 0);
    final rawList = raw['list'];
    return PagedResult<T>(
      list: rawList is List
          ? rawList
                .whereType<Map>()
                .map((item) => fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
      total: _asInt(raw['total']) ?? 0,
    );
  }
}

class Station {
  const Station({required this.stationId, required this.stationName});

  final String stationId;
  final String stationName;

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      stationId: json['stationId']?.toString() ?? '',
      stationName: json['stationName']?.toString() ?? '',
    );
  }
}

class HomeCategory {
  const HomeCategory({required this.categoryId, required this.categoryName});

  final String categoryId;
  final String categoryName;

  factory HomeCategory.fromJson(Map<String, dynamic> json) {
    return HomeCategory(
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
    );
  }
}

class ShopSummary {
  const ShopSummary({
    required this.shopId,
    required this.name,
    required this.imageUrl,
    required this.categoryName,
    required this.rating,
    required this.distance,
    this.couponPrice,
  });

  final String shopId;
  final String name;
  final String imageUrl;
  final String categoryName;
  final double rating;
  final int distance;
  final String? couponPrice;

  factory ShopSummary.fromJson(Map<String, dynamic> json) {
    return ShopSummary(
      shopId: json['shopId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      rating: (_asDouble(json['rating']) ?? 0).toStringAsFixed(1).asDouble(),
      distance: _asDouble(json['distance'])?.truncate() ?? 0,
      couponPrice: json['couponPrice']?.toString(),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

extension on String {
  double asDouble() => double.tryParse(this) ?? 0;
}
