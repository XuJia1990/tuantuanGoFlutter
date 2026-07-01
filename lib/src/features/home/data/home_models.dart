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

class ShopDetail {
  const ShopDetail({
    required this.shopId,
    required this.name,
    required this.rating,
    required this.nearestStation,
    required this.introduce,
    required this.address,
    required this.telephone,
    required this.latitude,
    required this.longitude,
    required this.isFav,
    required this.imageUrls,
    required this.categories,
  });

  final String shopId;
  final String name;
  final double rating;
  final String nearestStation;
  final String introduce;
  final String address;
  final String telephone;
  final double? latitude;
  final double? longitude;
  final bool isFav;
  final List<String> imageUrls;
  final List<HomeCategory> categories;

  factory ShopDetail.fromJson(Map<String, dynamic> json) {
    final rawImages = json['imageUrlList'];
    final rawZipImages = json['zipImageUrlList'];
    final rawCategories = json['categoryList'];
    return ShopDetail(
      shopId: json['shopId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rating: (_asDouble(json['rating']) ?? 0).toStringAsFixed(1).asDouble(),
      nearestStation: json['nearestStation']?.toString() ?? '',
      introduce: json['introduce']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      telephone: json['telephone']?.toString() ?? '',
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      isFav: json['isFav'] == true,
      imageUrls: _stringList(rawImages).isNotEmpty
          ? _stringList(rawImages)
          : _stringList(rawZipImages),
      categories: rawCategories is List
          ? rawCategories
                .whereType<Map>()
                .map(
                  (item) =>
                      HomeCategory.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }

  ShopDetail copyWith({bool? isFav}) {
    return ShopDetail(
      shopId: shopId,
      name: name,
      rating: rating,
      nearestStation: nearestStation,
      introduce: introduce,
      address: address,
      telephone: telephone,
      latitude: latitude,
      longitude: longitude,
      isFav: isFav ?? this.isFav,
      imageUrls: imageUrls,
      categories: categories,
    );
  }
}

class CouponSummary {
  const CouponSummary({
    required this.couponId,
    required this.couponName,
    required this.couponPrice,
    required this.oriPrice,
    required this.imageUrl,
  });

  final String couponId;
  final String couponName;
  final double couponPrice;
  final double oriPrice;
  final String imageUrl;

  double get savedPrice => oriPrice - couponPrice;

  factory CouponSummary.fromJson(Map<String, dynamic> json) {
    final rawImages = json['imageList'];
    return CouponSummary(
      couponId: json['couponId']?.toString() ?? '',
      couponName: json['couponName']?.toString() ?? '',
      couponPrice: _asDouble(json['couponPrice']) ?? 0,
      oriPrice: _asDouble(json['oriPrice']) ?? 0,
      imageUrl: rawImages is List && rawImages.isNotEmpty
          ? _couponImage(rawImages.first)
          : '',
    );
  }
}

class CouponMain {
  const CouponMain({
    required this.couponId,
    required this.shopName,
    required this.logoImageUrl,
    required this.categoryName,
    required this.distance,
    required this.couponName,
    required this.couponPrice,
    required this.oriPrice,
    required this.discountRate,
    required this.imageUrl,
  });

  final String couponId;
  final String shopName;
  final String logoImageUrl;
  final String categoryName;
  final int distance;
  final String couponName;
  final double couponPrice;
  final double oriPrice;
  final int discountRate;
  final String imageUrl;

  factory CouponMain.fromJson(Map<String, dynamic> json) {
    final rawImages = json['imageList'];
    final rawCategories = json['categoryList'];
    return CouponMain(
      couponId: json['couponId']?.toString() ?? '',
      shopName: json['name']?.toString() ?? '',
      logoImageUrl:
          json['logoImageURL']?.toString() ??
          json['logoImageUrl']?.toString() ??
          '',
      categoryName:
          rawCategories is List &&
              rawCategories.isNotEmpty &&
              rawCategories.first is Map
          ? HomeCategory.fromJson(
              Map<String, dynamic>.from(rawCategories.first as Map),
            ).categoryName
          : json['categoryName']?.toString() ?? '--',
      distance: _asDouble(json['distance'])?.truncate() ?? 0,
      couponName: json['couponName']?.toString() ?? '',
      couponPrice: _asDouble(json['couponPrice']) ?? 0,
      oriPrice: _asDouble(json['oriPrice']) ?? 0,
      discountRate: ((_asDouble(json['discountRate']) ?? 0) * 100).toInt(),
      imageUrl: rawImages is List && rawImages.isNotEmpty
          ? _couponImage(rawImages.first)
          : '',
    );
  }
}

class CouponDetail {
  const CouponDetail({
    required this.couponId,
    required this.couponName,
    required this.couponPrice,
    required this.oriPrice,
    required this.discountRate,
    required this.imageUrl,
    required this.items,
  });

  final String couponId;
  final String couponName;
  final double couponPrice;
  final double oriPrice;
  final int discountRate;
  final String imageUrl;
  final List<CouponDetailItem> items;

  int get offRate {
    if (oriPrice <= 0 || couponPrice <= 0 || couponPrice >= oriPrice) {
      return discountRate;
    }
    return ((1 - couponPrice / oriPrice) * 100).round();
  }

  factory CouponDetail.fromJson(Map<String, dynamic> json) {
    final rawImages = json['imageList'];
    final rawItems = json['couponDetailList'];
    return CouponDetail(
      couponId: json['couponId']?.toString() ?? '',
      couponName: json['couponName']?.toString() ?? '',
      couponPrice: _asDouble(json['couponPrice']) ?? 0,
      oriPrice: _asDouble(json['oriPrice']) ?? 0,
      discountRate: ((_asDouble(json['discountRate']) ?? 0) * 100).toInt(),
      imageUrl: rawImages is List && rawImages.isNotEmpty
          ? _couponImage(rawImages.first)
          : '',
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => CouponDetailItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class CouponDetailItem {
  const CouponDetailItem({
    required this.goodsName,
    required this.quantity,
    required this.unit,
  });

  final String goodsName;
  final String quantity;
  final String unit;

  factory CouponDetailItem.fromJson(Map<String, dynamic> json) {
    return CouponDetailItem(
      goodsName: json['goodsName']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
    );
  }
}

String _couponImage(dynamic raw) {
  if (raw is Map) {
    return raw['zipImageUrl']?.toString() ?? raw['imageUrl']?.toString() ?? '';
  }
  return raw?.toString() ?? '';
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
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
