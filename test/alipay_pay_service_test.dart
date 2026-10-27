import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_go_flutter/src/core/payment/alipay_pay_service.dart';
import 'package:url_launcher/url_launcher.dart';

Map<String, dynamic> _response({
  int code = 0,
  bool created = true,
  String? url = 'https://checkout.example.com/pay?token=signed-value',
  String? codeUrl,
  String resultCode = 'SUCCESS',
}) => {
  'code': code,
  'msg': '',
  'data': {
    'isSecces': created,
    'memberOrderId': 123456,
    'wechatPayInfo': {
      'return_code': 'SUCCESS',
      'result_code': resultCode,
      'redirect_url': url,
      'code_url': ?codeUrl,
    },
  },
};

void main() {
  test('accepts the documented EC response and existing app success code', () {
    for (final code in [0, 200]) {
      final payment = AlipayPayment.fromResponse(_response(code: code));
      expect(payment.memberOrderId, '123456');
      expect(payment.redirectUri.query, 'token=signed-value');
    }
  });

  test('accepts code_url when redirect_url is absent or blank', () {
    const codeUrl =
        'https://open-sea.alipayplus.com/api/open/v1/ac/cashier/self/codevalue/'
        'checkout.htm?codeValue=test%2Bvalue&other=1';
    for (final redirectUrl in [null, '', ' \n ']) {
      final response = _response(url: redirectUrl, codeUrl: codeUrl);
      if (redirectUrl == null) {
        ((response['data'] as Map)['wechatPayInfo'] as Map).remove(
          'redirect_url',
        );
      }
      final payment = AlipayPayment.fromResponse(response);
      expect(payment.redirectUri.toString(), codeUrl);
      expect(payment.memberOrderId, '123456');
    }
  });

  test('prefers redirect_url when both payment URL fields are present', () {
    final payment = AlipayPayment.fromResponse(
      _response(codeUrl: 'https://checkout.example.com/other'),
    );
    expect(
      payment.redirectUri.toString(),
      'https://checkout.example.com/pay?token=signed-value',
    );
  });

  test('applies the same validation to code_url', () {
    for (final codeUrl in [
      'http://checkout.example.com/pay',
      '/pay',
      'https:///pay',
      'https://user:password@checkout.example.com/pay',
      'javascript:alert(1)',
      'alipays://pay',
    ]) {
      expect(
        () =>
            AlipayPayment.fromResponse(_response(url: null, codeUrl: codeUrl)),
        throwsA(isA<AlipayPayException>()),
      );
    }
  });

  test('rejects failed API, order creation and EC results', () {
    for (final response in [
      _response(code: 500),
      _response(created: false),
      _response(resultCode: 'FAIL'),
      {'code': 0, 'data': null},
    ]) {
      expect(
        () => AlipayPayment.fromResponse(response),
        throwsA(isA<AlipayPayException>()),
      );
    }
  });

  test('rejects missing order ID or payment details', () {
    for (final key in ['memberOrderId', 'wechatPayInfo']) {
      final response = _response();
      (response['data'] as Map).remove(key);
      expect(
        () => AlipayPayment.fromResponse(response),
        throwsA(isA<AlipayPayException>()),
      );
    }
  });

  test('rejects missing, relative, insecure and non-web checkout URLs', () {
    for (final url in [
      null,
      '',
      '/pay',
      'http://checkout.example.com/pay',
      'https:///pay',
      'https://user:password@checkout.example.com/pay',
      'alipays://pay',
      'javascript:alert(1)',
    ]) {
      expect(
        () => AlipayPayment.fromResponse(_response(url: url)),
        throwsA(isA<AlipayPayException>()),
      );
    }
  });

  test('launches the exact EC URL in an external application', () async {
    Uri? launchedUri;
    LaunchMode? launchedMode;
    final service = AlipayPayService(
      launcher: (url, {mode = LaunchMode.platformDefault}) async {
        launchedUri = url;
        launchedMode = mode;
        return true;
      },
    );
    final payment = AlipayPayment.fromResponse(_response());
    await service.openPaymentPage(payment);
    expect(launchedUri, payment.redirectUri);
    expect(launchedMode, LaunchMode.externalApplication);
  });

  test(
    'reports browser launch failures without claiming payment failure',
    () async {
      final payment = AlipayPayment.fromResponse(_response());
      for (final throws in [false, true]) {
        final service = AlipayPayService(
          launcher: (_, {mode = LaunchMode.platformDefault}) async {
            if (throws) throw PlatformException(code: 'launch_failed');
            return false;
          },
        );
        await expectLater(
          service.openPaymentPage(payment),
          throwsA(isA<AlipayPayException>()),
        );
      }
    },
  );
}
