import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/payment/alipay_pay_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/tuantuan_endpoints.dart';
import 'home_models.dart';

final couponAlipayGatewayProvider = Provider<CouponAlipayGateway>(
  (ref) => ApiCouponAlipayGateway(ref.watch(apiClientProvider)),
);

abstract interface class CouponAlipayGateway {
  Future<String> createOrder(String couponId);

  Future<AlipayPayment> getPayment(String orderId);

  /// True only when the backend confirms this coupon order is paid.
  Future<bool> isPaid(String orderId);
}

class ApiCouponAlipayGateway implements CouponAlipayGateway {
  ApiCouponAlipayGateway(this._api);

  final ApiClient _api;

  @override
  Future<String> createOrder(String couponId) async {
    final raw = await _api.post(
      TuanTuanEndpoints.createOrder,
      data: {'couponId': couponId, 'tradMethod': '25'},
    );
    final data = _paymentData(raw, '创建支付宝订单失败');
    final orderId = data['OrderMgmtId']?.toString().trim() ?? '';
    if (orderId.isEmpty) throw const AlipayPayException('优惠券订单号缺失');
    return orderId;
  }

  @override
  Future<AlipayPayment> getPayment(String orderId) async {
    final raw = await _api.get(
      TuanTuanEndpoints.payInfo,
      query: {'orderId': orderId},
    );
    return AlipayPayment.fromPayInfo(
      orderId: orderId,
      payInfo: _paymentData(raw, '获取支付宝支付信息失败'),
    );
  }

  @override
  Future<bool> isPaid(String orderId) async {
    final raw = await _api.get(
      TuanTuanEndpoints.payStatus,
      query: {'orderId': orderId},
    );
    // Same server confirmation contract used by the existing coupon WeChat flow.
    return ApiEnvelope.parse<void>(raw, (_) {}).isSuccess;
  }

  Map<String, dynamic> _paymentData(Object? raw, String fallback) {
    final envelope = ApiEnvelope.parse<Map<String, dynamic>>(
      raw,
      (data) => data is Map ? Map<String, dynamic>.from(data) : {},
    );
    if (!envelope.isSuccess || envelope.data == null) {
      throw AlipayPayException(envelope.message ?? fallback);
    }
    return envelope.data!;
  }
}
