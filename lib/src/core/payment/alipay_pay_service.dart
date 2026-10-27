import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final alipayPayServiceProvider = Provider((ref) => AlipayPayService());

class AlipayReturnRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final alipayReturnRevisionProvider =
    NotifierProvider<AlipayReturnRevision, int>(AlipayReturnRevision.new);

/// EC supplies a hosted checkout URL, rather than native Alipay SDK parameters.
class AlipayPayment {
  const AlipayPayment({required this.memberOrderId, required this.redirectUri});

  final String memberOrderId;
  final Uri redirectUri;

  factory AlipayPayment.fromResponse(Object? response) {
    if (response is! Map) {
      throw const AlipayPayException('支付宝订单响应格式错误');
    }
    final code = response['code']?.toString();
    // The EC contract uses 0; existing app APIs use 200.
    if (code != '0' && code != '200') {
      final message = response['msg']?.toString().trim();
      throw AlipayPayException(
        message == null || message.isEmpty ? '创建支付宝充值订单失败' : message,
      );
    }
    final data = response['data'];
    if (data is! Map) {
      throw const AlipayPayException('支付宝订单响应格式错误');
    }
    return AlipayPayment.fromJson(Map<String, dynamic>.from(data));
  }

  factory AlipayPayment.fromJson(Map<String, dynamic> json) {
    if (json['isSecces'] != true) {
      throw const AlipayPayException('创建支付宝充值订单失败');
    }
    final orderId = json['memberOrderId']?.toString().trim() ?? '';
    if (orderId.isEmpty) {
      throw const AlipayPayException('支付宝充值订单号缺失');
    }
    final payInfo = json['wechatPayInfo'];
    if (payInfo is! Map) {
      throw const AlipayPayException('支付宝支付信息缺失');
    }
    for (final key in ['return_code', 'result_code']) {
      final code = payInfo[key]?.toString();
      if (code != null && code != 'SUCCESS') {
        throw const AlipayPayException('支付宝支付订单创建失败，请稍后重试');
      }
    }
    final redirectUrl = payInfo['redirect_url']?.toString().trim() ?? '';
    // Some gateway responses put the hosted checkout URL in code_url.
    final rawUrl = redirectUrl.isNotEmpty
        ? redirectUrl
        : payInfo['code_url']?.toString().trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const AlipayPayException('支付宝支付地址无效，请稍后重试');
    }
    return AlipayPayment(memberOrderId: orderId, redirectUri: uri);
  }
}

class AlipayPayService {
  AlipayPayService({
    Future<bool> Function(Uri url, {LaunchMode mode})? launcher,
  }) : _launcher = launcher ?? _launchUrl;

  final Future<bool> Function(Uri url, {LaunchMode mode}) _launcher;

  static Future<bool> _launchUrl(
    Uri url, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) => launchUrl(url, mode: mode);

  Future<void> openPaymentPage(AlipayPayment payment) async {
    try {
      final launched = await _launcher(
        payment.redirectUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AlipayPayException('无法打开浏览器，请重试');
      }
    } on AlipayPayException {
      rethrow;
    } catch (_) {
      throw const AlipayPayException('无法打开浏览器，请重试');
    }
  }
}

class AlipayPayException implements Exception {
  const AlipayPayException(this.message);

  final String message;

  @override
  String toString() => message;
}
