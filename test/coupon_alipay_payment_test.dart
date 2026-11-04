import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_go_flutter/src/app/router/alipay_return_guard.dart';
import 'package:tuantuan_go_flutter/src/core/network/api_client.dart';
import 'package:tuantuan_go_flutter/src/core/network/tuantuan_endpoints.dart';
import 'package:tuantuan_go_flutter/src/core/payment/alipay_pay_service.dart';
import 'package:tuantuan_go_flutter/src/features/home/data/coupon_alipay_gateway.dart';
import 'package:tuantuan_go_flutter/src/features/home/presentation/submit_order_page.dart';
import 'package:url_launcher/url_launcher.dart';

class _CouponApi implements ApiClient {
  final mutations = <String>[];
  final queries = <({String path, Map<String, dynamic>? query})>[];
  bool paid = false;
  String checkout = 'https://checkout.example.com/pay?token=signed%2B42';

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async {
    queries.add((path: path, query: query));
    if (path == TuanTuanEndpoints.payInfo) {
      return {
        'code': 200,
        'data': {'code_url': checkout},
      };
    }
    if (path == TuanTuanEndpoints.payStatus) {
      return {'code': paid ? 200 : 500, 'msg': paid ? '' : '支付尚未完成'};
    }
    expect(path, TuanTuanEndpoints.couponInfo);
    return {
      'code': 200,
      'data': {
        'name': '测试店铺',
        'couponName': '测试优惠券',
        'couponPrice': 10,
        'exchangeCodeFlag': 1,
      },
    };
  }

  @override
  Future<dynamic> post(String path, {Object? data}) async {
    mutations.add(path);
    final uri = Uri.parse(path);
    expect(uri.path, TuanTuanEndpoints.createOrder);
    expect(uri.hasQuery, isFalse);
    expect(data, {'couponId': 'coupon-9', 'tradMethod': '25'});
    return {
      'code': 200,
      'data': {'OrderMgmtId': '42'},
    };
  }

  @override
  Future<dynamic> delete(String path, {Object? data}) async {
    mutations.add(path);
    throw StateError('Do not delete a pending Alipay order');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gateway implements CouponAlipayGateway {
  final createdFor = <String>[];
  final checkedOrders = <String>[];
  bool paid = false;
  bool statusError = false;
  bool payInfoError = false;
  final paymentOrders = <String>[];
  Completer<void>? beforeStatus;

  @override
  Future<String> createOrder(String couponId) async {
    createdFor.add(couponId);
    return 'coupon-order-42';
  }

  @override
  Future<AlipayPayment> getPayment(String orderId) async {
    paymentOrders.add(orderId);
    if (payInfoError) throw const AlipayPayException('获取支付宝支付信息失败');
    return AlipayPayment.forOrder(
      orderId: 'coupon-order-42',
      redirectUri: Uri.parse(
        'https://checkout.example.com/pay?token=signed%2B42',
      ),
    );
  }

  @override
  Future<bool> isPaid(String orderId) async {
    checkedOrders.add(orderId);
    await beforeStatus?.future;
    if (statusError) throw StateError('network unavailable');
    return paid;
  }
}

Future<({GoRouter router, _CouponApi api})> _show(
  WidgetTester tester, {
  _Gateway? gateway,
  AlipayPayService? browser,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = _CouponApi();
  late ProviderContainer container;
  final router = GoRouter(
    initialLocation: '/submit-order',
    onEnter: alipayReturnGuard(
      checkPendingPayment: () =>
          container.read(alipayReturnRevisionProvider.notifier).bump(),
    ),
    routes: [
      GoRoute(
        path: '/submit-order',
        builder: (_, _) => const SubmitOrderPage(couponId: 'coupon-9'),
      ),
      GoRoute(
        path: '/coupon-order-detail',
        builder: (_, state) =>
            Text('paid:${state.uri.queryParameters['orderId']}'),
      ),
      GoRoute(path: '/member', builder: (_, _) => const Text('member')),
      GoRoute(
        path: '/purchased-coupons',
        builder: (_, _) => const Text('purchased coupons'),
      ),
    ],
  );
  container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      if (gateway != null)
        couponAlipayGatewayProvider.overrideWithValue(gateway),
      alipayPayServiceProvider.overrideWithValue(
        browser ??
            AlipayPayService(
              launcher: (_, {mode = LaunchMode.platformDefault}) async => true,
            ),
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (router: router, api: api);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('支付宝支付'));
  await tester.pump();
  await tester.tap(find.text('支付宝支付').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sends couponId and tradMethod 25 in the JSON request body', (
    tester,
  ) async {
    final result = await _show(tester);
    expect(find.text('微信支付'), findsNWidgets(2));
    expect(find.text('兑换码'), findsOneWidget);
    await _submit(tester);
    expect(result.api.mutations, hasLength(1));
    expect(find.text('等待支付完成'), findsOneWidget);
    expect(result.api.queries.last.path, TuanTuanEndpoints.payInfo);
    expect(result.api.queries.last.query, {'orderId': '42'});
    result.router.go(AlipayReturnLink.appUrl);
    await tester.pumpAndSettle();
    expect(find.text('等待支付完成'), findsOneWidget);
    expect(result.api.queries.last.path, TuanTuanEndpoints.payStatus);
    expect(result.api.queries.last.query, {'orderId': '42'});
    result.api.paid = true;
    await tester.ensureVisible(find.text('我已支付，确认订单'));
    await tester.tap(find.text('我已支付，确认订单'));
    await tester.pumpAndSettle();
    expect(find.text('paid:42'), findsOneWidget);
    expect(result.api.mutations, hasLength(1));
  });

  testWidgets(
    'browser failure retries the same checkout without another order',
    (tester) async {
      final gateway = _Gateway();
      final opened = <Uri>[];
      final result = await _show(
        tester,
        gateway: gateway,
        browser: AlipayPayService(
          launcher: (uri, {mode = LaunchMode.platformDefault}) async {
            expect(mode, LaunchMode.externalApplication);
            opened.add(uri);
            return opened.length > 1;
          },
        ),
      );
      await _submit(tester);
      expect(find.text('支付宝购买优惠券'), findsOneWidget);
      expect(find.text('余额到账'), findsNothing);
      expect(find.text('无法打开浏览器，请重试'), findsOneWidget);
      await tester.ensureVisible(find.text('重新打开支付页面'));
      await tester.tap(find.text('重新打开支付页面'));
      await tester.pumpAndSettle();
      expect(opened, hasLength(2));
      expect(opened.first, opened.last);
      expect(gateway.createdFor, ['coupon-9']);
      expect(result.api.mutations, isEmpty);
    },
  );

  testWidgets('payinfo failure preserves the created order for retry', (
    tester,
  ) async {
    final gateway = _Gateway()..payInfoError = true;
    final opened = <Uri>[];
    final result = await _show(
      tester,
      gateway: gateway,
      browser: AlipayPayService(
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await _submit(tester);
    expect(find.text('获取支付宝支付信息失败'), findsOneWidget);
    expect(opened, isEmpty);
    gateway.payInfoError = false;
    await tester.ensureVisible(find.text('重新打开支付页面'));
    await tester.tap(find.text('重新打开支付页面'));
    await tester.pumpAndSettle();
    expect(gateway.createdFor, hasLength(1));
    expect(gateway.paymentOrders, ['coupon-order-42', 'coupon-order-42']);
    expect(opened, hasLength(1));
    expect(result.api.mutations, isEmpty);
  });

  testWidgets(
    'invalid gateway URL never launches and never creates another order',
    (tester) async {
      final opened = <Uri>[];
      final result = await _show(
        tester,
        browser: AlipayPayService(
          launcher: (uri, {mode = LaunchMode.platformDefault}) async {
            opened.add(uri);
            return true;
          },
        ),
      );
      result.api.checkout = 'javascript:alert(1)';
      await _submit(tester);
      expect(opened, isEmpty);
      expect(find.text('支付宝支付地址无效，请稍后重试'), findsOneWidget);
      result.api.checkout =
          'https://checkout.example.com/pay?token=signed%2B42';
      await tester.ensureVisible(find.text('重新打开支付页面'));
      await tester.tap(find.text('重新打开支付页面'));
      await tester.pumpAndSettle();
      expect(result.api.mutations, hasLength(1));
      expect(
        result.api.queries
            .where((r) => r.path == TuanTuanEndpoints.payInfo)
            .map((r) => r.query?['orderId']),
        ['42', '42'],
      );
      expect(opened, hasLength(1));
    },
  );

  testWidgets('returning from browser checks the original order on resume', (
    tester,
  ) async {
    final gateway = _Gateway()..paid = true;
    await _show(tester, gateway: gateway);
    await _submit(tester);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(find.text('paid:coupon-order-42'), findsOneWidget);
    expect(gateway.checkedOrders, ['coupon-order-42']);
  });

  for (final error in [false, true]) {
    testWidgets('return link keeps pending order when status error=$error', (
      tester,
    ) async {
      final gateway = _Gateway()..statusError = error;
      final result = await _show(tester, gateway: gateway);
      await _submit(tester);
      result.router.go(
        '${AlipayReturnLink.appUrl}?status=success&orderId=untrusted',
      );
      await tester.pumpAndSettle();
      expect(
        result.router.routerDelegate.currentConfiguration.uri.path,
        '/submit-order',
      );
      expect(gateway.checkedOrders, ['coupon-order-42']);
      expect(gateway.createdFor, hasLength(1));
      expect(find.text('等待支付完成'), findsOneWidget);
      expect(find.textContaining('已付款请勿重复支付'), findsOneWidget);
      expect(result.api.mutations, isEmpty);
    });
  }

  testWidgets('server confirmation opens the original coupon order', (
    tester,
  ) async {
    final gateway = _Gateway()..paid = true;
    final result = await _show(tester, gateway: gateway);
    await _submit(tester);
    result.router.go(AlipayReturnLink.appUrl);
    await tester.pumpAndSettle();
    expect(find.text('paid:coupon-order-42'), findsOneWidget);
    expect(gateway.checkedOrders, ['coupon-order-42']);
    expect(result.api.mutations, isEmpty);
  });

  testWidgets('status checks cannot overlap after repeated return callbacks', (
    tester,
  ) async {
    final gateway = _Gateway()..beforeStatus = Completer<void>();
    final result = await _show(tester, gateway: gateway);
    await _submit(tester);
    result.router.go(AlipayReturnLink.appUrl);
    await tester.pump();
    result.router.go(AlipayReturnLink.appUrl);
    await tester.pump();
    expect(gateway.checkedOrders, hasLength(1));
    gateway.beforeStatus!.complete();
    await tester.pumpAndSettle();
    expect(gateway.createdFor, hasLength(1));
  });
}
