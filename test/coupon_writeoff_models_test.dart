import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_go_flutter/src/features/shop_manager/data/coupon_writeoff_models.dart';

void main() {
  test('parses coupon writeoff page and display fields', () {
    final page = CouponWriteoffPage.fromRaw({
      'timeZone': 'Asia/Tokyo',
      'total': 1,
      'redeemedCount': 1,
      'list': [
        {
          'orderMgmtId': 1001,
          'couponId': 99,
          'couponName': '整龙虾优惠券',
          'contents': [
            {'goodsName': '整龙虾', 'quantity': 1, 'unit': '份'},
          ],
          'shopName': '上野店',
          'userNickname': '顾客',
          'userMobile': '+81****5678',
          'isShopMember': true,
          'writeoffUserNickname': '店员',
          'source': 'ACTIVITY_REWARD',
          'activityName': '集章活动',
          'receivedTime': '2026-10-01 12:00:00',
          'writeoffTime': '2026-10-21 15:00:00',
        },
      ],
    });

    expect(page.total, 1);
    expect(page.redeemedCount, 1);
    expect(page.list.single.dateGroup, '2026-10-21');
    expect(page.list.single.sourceText, '活动奖励');
    expect(page.list.single.isShopMember, isTrue);
    expect(page.list.single.holderText, '顾客【V】  +81****5678');
    expect(page.list.single.operatorText, '店员');
    expect(page.list.single.contentText, '整龙虾 x1份');
  });

  test('uses documented fallbacks for missing historical data', () {
    final record = CouponWriteoffRecord.fromJson({
      'couponId': 7,
      'source': null,
      'writeoffTime': null,
      'writeoffUserNickname': null,
    });

    expect(record.displayCouponName, '优惠券 #7');
    expect(record.dateGroup, '未记录日期');
    expect(record.sourceText, '未记录来源');
    expect(record.isShopMember, isFalse);
    expect(record.holderText, '未记录');
    expect(record.operatorText, '未记录');
  });
}
