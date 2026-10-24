class CouponWriteoffPage {
  const CouponWriteoffPage({
    required this.timeZone,
    required this.total,
    required this.redeemedCount,
    required this.list,
  });

  final String timeZone;
  final int total;
  final int redeemedCount;
  final List<CouponWriteoffRecord> list;

  factory CouponWriteoffPage.fromRaw(dynamic raw) {
    if (raw is! Map) {
      return const CouponWriteoffPage(
        timeZone: 'Asia/Tokyo',
        total: 0,
        redeemedCount: 0,
        list: [],
      );
    }
    final list = raw['list'];
    return CouponWriteoffPage(
      timeZone: _text(raw['timeZone'], fallback: 'Asia/Tokyo'),
      total: _int(raw['total']),
      redeemedCount: _int(raw['redeemedCount']),
      list: list is List
          ? list
                .whereType<Map>()
                .map(
                  (item) => CouponWriteoffRecord.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class CouponWriteoffRecord {
  const CouponWriteoffRecord({
    required this.orderMgmtId,
    required this.couponId,
    required this.couponName,
    required this.imageUrl,
    required this.contents,
    required this.shopName,
    required this.userNickname,
    required this.userMobile,
    required this.writeoffUserNickname,
    required this.source,
    required this.activityName,
    required this.receivedTime,
    required this.writeoffTime,
  });

  final int orderMgmtId;
  final int couponId;
  final String couponName;
  final String imageUrl;
  final List<CouponWriteoffContent> contents;
  final String shopName;
  final String userNickname;
  final String userMobile;
  final String writeoffUserNickname;
  final String source;
  final String activityName;
  final String receivedTime;
  final String writeoffTime;

  String get dateGroup {
    if (writeoffTime.length >= 10) return writeoffTime.substring(0, 10);
    return '未记录日期';
  }

  String get displayCouponName => couponName.isNotEmpty
      ? couponName
      : couponId > 0
      ? '优惠券 #$couponId'
      : '优惠券';

  String get sourceText => switch (source) {
    'PURCHASE' => '购买',
    'EXCHANGE_CODE' => '兑换码',
    'ADMIN_GRANT' => '指定发放',
    'ACTIVITY_REWARD' => '活动奖励',
    _ => source.isEmpty ? '未记录来源' : source,
  };

  String get holderText {
    if (userNickname.isNotEmpty && userMobile.isNotEmpty) {
      return '$userNickname  $userMobile';
    }
    return userNickname.isNotEmpty
        ? userNickname
        : userMobile.isNotEmpty
        ? userMobile
        : '未记录';
  }

  String get operatorText =>
      writeoffUserNickname.isEmpty ? '未记录' : writeoffUserNickname;

  String get contentText => contents
      .map((item) => item.displayText)
      .where((item) => item.isNotEmpty)
      .join('、');

  factory CouponWriteoffRecord.fromJson(Map<String, dynamic> json) {
    final contents = json['contents'];
    return CouponWriteoffRecord(
      orderMgmtId: _int(json['orderMgmtId']),
      couponId: _int(json['couponId']),
      couponName: _text(json['couponName']),
      imageUrl: _text(json['imageUrl']),
      contents: contents is List
          ? contents
                .whereType<Map>()
                .map(
                  (item) => CouponWriteoffContent.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      shopName: _text(json['shopName']),
      userNickname: _text(json['userNickname']),
      userMobile: _text(json['userMobile']),
      writeoffUserNickname: _text(json['writeoffUserNickname']),
      source: _text(json['source']),
      activityName: _text(json['activityName']),
      receivedTime: _text(json['receivedTime']),
      writeoffTime: _text(json['writeoffTime']),
    );
  }
}

class CouponWriteoffContent {
  const CouponWriteoffContent({
    required this.goodsName,
    required this.quantity,
    required this.unit,
  });

  final String goodsName;
  final num quantity;
  final String unit;

  String get displayText {
    if (goodsName.isEmpty) return '';
    final quantityText = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return '$goodsName x$quantityText$unit';
  }

  factory CouponWriteoffContent.fromJson(Map<String, dynamic> json) {
    return CouponWriteoffContent(
      goodsName: _text(json['goodsName']),
      quantity: _num(json['quantity']),
      unit: _text(json['unit']),
    );
  }
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

num _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}
