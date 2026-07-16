import 'dart:convert';
import 'dart:developer' as developer;

import 'package:fluwx/fluwx.dart';

class WeChatPayConfig {
  const WeChatPayConfig._();

  static const appId = 'wx65404f22040dbe4d';
  static const universalLink = 'https://share.tuantuan-go.com/';
}

class WeChatPayService {
  WeChatPayService._();

  static final instance = WeChatPayService._();

  final fluwx = Fluwx();
  var _registered = false;
  String? _initError;

  Future<bool> init() async {
    if (_registered) return true;
    try {
      _registered = await fluwx.registerApi(
        appId: WeChatPayConfig.appId,
        doOnAndroid: true,
        doOnIOS: true,
        universalLink: WeChatPayConfig.universalLink,
      );
      if (!_registered) {
        _initError = '微信支付初始化失败: registerApp 返回 false';
        _logPayment('init_failed', {'reason': _initError});
      } else {
        _initError = null;
      }
    } catch (error, stackTrace) {
      _registered = false;
      _initError = '微信支付初始化失败: $error';
      _logPayment(
        'init_exception',
        {'reason': error.toString()},
        error: error,
        stackTrace: stackTrace,
      );
    }
    return _registered;
  }

  Future<bool> get isWeChatInstalled => fluwx.isWeChatInstalled;

  Future<bool> pay(Map<String, dynamic> payInfo) async {
    final ready = await init();
    if (!ready) {
      throw WeChatPayException(_initError ?? '微信支付初始化失败');
    }
    final payment = _paymentFromPayInfo(payInfo);
    final launched = await fluwx.pay(which: payment);
    _logPayment('send_req', {
      'launched': launched,
      'appId': payment.appId,
      'partnerId': payment.partnerId,
      'prepayId': payment.prepayId,
      'packageValue': payment.packageValue,
      'timestamp': payment.timestamp,
      'signType': payment.signType,
      'hasSign': payment.sign.isNotEmpty,
    });
    return launched;
  }

  Payment _paymentFromPayInfo(Map<String, dynamic> payInfo) {
    final appId = _string(payInfo['o_appid']);
    final partnerId = _string(payInfo['o_partnerid']);
    final prepayId = _string(payInfo['o_prepayid']);
    final packageValue = _string(payInfo['o_package'], fallback: 'Sign=WXPay');
    final nonceStr = _string(payInfo['o_noncestr']);
    final timestamp = _int(payInfo['o_timestamp']);
    final sign = _string(
      payInfo['o_sign'] ?? payInfo['sign'] ?? payInfo['paySign'],
    );
    final signType = _optionalString(payInfo['sign_type']);

    final missing = <String>[
      if (appId.isEmpty) 'o_appid',
      if (partnerId.isEmpty) 'o_partnerid',
      if (prepayId.isEmpty) 'o_prepayid',
      if (packageValue.isEmpty) 'o_package',
      if (nonceStr.isEmpty) 'o_noncestr',
      if (timestamp == 0) 'o_timestamp',
      if (sign.isEmpty) 'o_sign',
    ];
    if (missing.isNotEmpty) {
      throw WeChatPayException('支付参数缺失: ${missing.join(', ')}');
    }
    if (appId != WeChatPayConfig.appId) {
      throw WeChatPayException(
        '支付AppID不一致: 服务端=$appId, 客户端=${WeChatPayConfig.appId}',
      );
    }

    return Payment(
      appId: appId,
      partnerId: partnerId,
      prepayId: prepayId,
      packageValue: packageValue,
      nonceStr: nonceStr,
      timestamp: timestamp,
      sign: sign,
      signType: signType,
    );
  }

  String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _optionalString(dynamic value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _logPayment(
    String event,
    Map<String, dynamic> data, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      const JsonEncoder.withIndent('  ').convert({
        'type': 'wechat_payment',
        'event': event,
        'appId': WeChatPayConfig.appId,
        'universalLink': WeChatPayConfig.universalLink,
        ...data,
      }),
      name: 'WeChatPay',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class WeChatPayException implements Exception {
  const WeChatPayException(this.message);

  final String message;

  @override
  String toString() => message;
}
