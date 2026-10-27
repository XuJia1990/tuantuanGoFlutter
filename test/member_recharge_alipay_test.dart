import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuantuan_go_flutter/src/core/constants/storage_keys.dart';
import 'package:tuantuan_go_flutter/src/core/network/api_client.dart';
import 'package:tuantuan_go_flutter/src/core/network/tuantuan_endpoints.dart';
import 'package:tuantuan_go_flutter/src/core/payment/alipay_pay_service.dart';
import 'package:tuantuan_go_flutter/src/features/member/presentation/member_recharge_page.dart';
import 'package:url_launcher/url_launcher.dart';

class _RechargeApi implements ApiClient {
  final posts = <({String path, Object? data})>[];
  int responseCode = 0;
  String? redirectUrl = 'https://checkout.example.com/pay?order=123456';
  String? codeUrl;
  bool paid = false;
  int statusCode = 200;
  int chargeCode = 200;
  Completer<void>? beforeCharge;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async => {
    'code': 200,
    'data': {'shopId': 1, 'name': '测试店铺'},
  };

  @override
  Future<dynamic> post(String path, {Object? data}) async {
    posts.add((path: path, data: data));
    if (path == TuanTuanEndpoints.wechatChargeOrderStatus) {
      return {
        'code': statusCode,
        'data': {'isFinished': paid},
        'msg': statusCode == 200 ? '' : '当前订单状态无法查询',
      };
    }
    if (path == TuanTuanEndpoints.chargeMember) {
      await beforeCharge?.future;
      return {
        'code': chargeCode,
        'data': {'chargeMoney': 100, 'money': 500},
        'msg': chargeCode == 200 ? '' : '确认充值失败',
      };
    }
    if (path != TuanTuanEndpoints.createAlipayMember) {
      throw StateError('Unexpected payment/charge request: $path');
    }
    return {
      'code': responseCode,
      'data': {
        'isSecces': true,
        'memberOrderId': 123456,
        'wechatPayInfo': {
          'return_code': 'SUCCESS',
          'result_code': 'SUCCESS',
          'redirect_url': redirectUrl,
          'code_url': ?codeUrl,
        },
      },
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _showRecharge(
  WidgetTester tester,
  _RechargeApi api,
  AlipayPayService browser,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({
    StorageKeys.userDetail: jsonEncode({'userId': 7}),
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        alipayPayServiceProvider.overrideWithValue(browser),
      ],
      child: const MaterialApp(
        home: MemberRechargePage(params: {'type': '1', 'shopId': '1'}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitAlipay(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), '100');
  await tester.enterText(find.byType(TextField).at(1), '100');
  await tester.ensureVisible(find.text('支付宝'));
  await tester.tap(find.text('支付宝'));
  await tester.tap(find.text('确认充值'));
  await tester.pumpAndSettle();
}

void _returnFromBrowser(WidgetTester tester) {
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
}

void main() {
  testWidgets('opens Alipay checkout returned in code_url', (tester) async {
    final api = _RechargeApi()
      ..redirectUrl = null
      ..codeUrl =
          'https://open-sea.alipayplus.com/api/open/v1/ac/cashier/self/codevalue/'
          'checkout.htm?codeValue=test%2Bvalue';
    final opened = <Uri>[];
    await _showRecharge(
      tester,
      api,
      AlipayPayService(
        launcher: (url, {mode = LaunchMode.platformDefault}) async {
          expect(mode, LaunchMode.externalApplication);
          opened.add(url);
          return true;
        },
      ),
    );
    await _submitAlipay(tester);
    expect(opened.single.toString(), api.codeUrl);
    expect(api.posts, hasLength(1));
    expect(find.text('等待支付完成'), findsOneWidget);
    expect(find.text('支付宝支付地址无效，请稍后重试'), findsNothing);
    expect(find.text('充值成功'), findsNothing);
  });

  testWidgets(
    'creates an EC order and checks on return without charging unpaid orders',
    (tester) async {
      final api = _RechargeApi();
      final opened = <Uri>[];
      final modes = <LaunchMode>[];
      await _showRecharge(
        tester,
        api,
        AlipayPayService(
          launcher: (url, {mode = LaunchMode.platformDefault}) async {
            opened.add(url);
            modes.add(mode);
            return true;
          },
        ),
      );
      expect(find.text('微信'), findsOneWidget);
      expect(find.text('支付宝'), findsOneWidget);
      await _submitAlipay(tester);

      expect(api.posts, hasLength(1));
      expect(api.posts.single.path, TuanTuanEndpoints.createAlipayMember);
      expect(api.posts.single.data, {
        'chargeWay': '25',
        'chargeMoney': 100,
        'isShopCharge': 0,
        'chargeShopId': 1,
        'chargeUserId': 7,
        'remark': '',
      });
      expect(opened.single.toString(), api.redirectUrl);
      expect(modes.single, LaunchMode.externalApplication);
      expect(find.text('等待支付完成'), findsOneWidget);
      expect(find.text('充值成功'), findsNothing);

      _returnFromBrowser(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(api.posts, hasLength(4));
      expect(
        api.posts.where((post) => post.path == TuanTuanEndpoints.chargeMember),
        isEmpty,
      );
      expect(find.text('充值成功'), findsNothing);

      await tester.tap(find.text('重新打开支付页面'));
      await tester.pumpAndSettle();
      expect(opened, hasLength(2));
      expect(opened.first, opened.last);
      expect(api.posts, hasLength(4));
    },
  );

  testWidgets(
    'confirms a paid order before charging and shows the new balance',
    (tester) async {
      final api = _RechargeApi()..paid = true;
      await _showRecharge(
        tester,
        api,
        AlipayPayService(
          launcher: (_, {mode = LaunchMode.platformDefault}) async => true,
        ),
      );
      await _submitAlipay(tester);
      expect(api.posts, hasLength(1));
      await tester.tap(find.text('我已支付，确认充值'));
      await tester.pumpAndSettle();
      expect(api.posts.map((post) => post.path), [
        TuanTuanEndpoints.createAlipayMember,
        TuanTuanEndpoints.wechatChargeOrderStatus,
        TuanTuanEndpoints.chargeMember,
      ]);
      expect(api.posts[1].data, {'memberOrderId': '123456'});
      expect(api.posts[2].data, {
        'isCreateFlg': false,
        'memberOrderId': '123456',
        'userId': '7',
      });
      expect(find.text('充值成功'), findsOneWidget);
      expect(find.text('100元\n卡内余额: 500元'), findsOneWidget);
      expect(find.text('重新打开支付页面'), findsNothing);
    },
  );

  testWidgets('returning from Alipay automatically confirms a paid order', (
    tester,
  ) async {
    final api = _RechargeApi()..paid = true;
    await _showRecharge(
      tester,
      api,
      AlipayPayService(
        launcher: (_, {mode = LaunchMode.platformDefault}) async => true,
      ),
    );
    await _submitAlipay(tester);
    _returnFromBrowser(tester);
    await tester.pumpAndSettle();
    expect(find.text('充值成功'), findsOneWidget);
    expect(api.posts, hasLength(3));
    _returnFromBrowser(tester);
    await tester.pumpAndSettle();
    expect(api.posts, hasLength(3));
  });

  testWidgets('an app return link checks the existing pending order', (
    tester,
  ) async {
    final api = _RechargeApi()..paid = true;
    await _showRecharge(
      tester,
      api,
      AlipayPayService(
        launcher: (_, {mode = LaunchMode.platformDefault}) async => true,
      ),
    );
    await _submitAlipay(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MemberRechargePage)),
    );
    container.read(alipayReturnRevisionProvider.notifier).bump();
    await tester.pumpAndSettle();
    expect(api.posts, hasLength(3));
    expect(api.posts[1].data, {'memberOrderId': '123456'});
    expect(find.text('充值成功'), findsOneWidget);
  });

  testWidgets('does not charge when the payment check fails', (tester) async {
    final api = _RechargeApi()..statusCode = 500;
    await _showRecharge(
      tester,
      api,
      AlipayPayService(
        launcher: (_, {mode = LaunchMode.platformDefault}) async => true,
      ),
    );
    await _submitAlipay(tester);
    await tester.tap(find.text('我已支付，确认充值'));
    await tester.pumpAndSettle();
    expect(api.posts, hasLength(2));
    expect(find.textContaining('当前订单状态无法查询'), findsOneWidget);
    expect(find.text('充值成功'), findsNothing);
    expect(find.text('我已支付，确认充值'), findsOneWidget);
  });

  testWidgets('does not duplicate a charge while a confirmation is in flight', (
    tester,
  ) async {
    final api = _RechargeApi()
      ..paid = true
      ..beforeCharge = Completer<void>();
    await _showRecharge(
      tester,
      api,
      AlipayPayService(
        launcher: (_, {mode = LaunchMode.platformDefault}) async => true,
      ),
    );
    await _submitAlipay(tester);
    await tester.tap(find.text('我已支付，确认充值'));
    await tester.pump();
    _returnFromBrowser(tester);
    await tester.pump();
    expect(api.posts, hasLength(3));
    api.beforeCharge!.complete();
    await tester.pumpAndSettle();
    expect(api.posts, hasLength(3));
    expect(find.text('充值成功'), findsOneWidget);
  });

  testWidgets('retries recharge confirmation for the same paid order', (
    tester,
  ) async {
    final api = _RechargeApi()
      ..paid = true
      ..chargeCode = 500;
    await _showRecharge(
      tester,
      api,
      AlipayPayService(
        launcher: (_, {mode = LaunchMode.platformDefault}) async => true,
      ),
    );
    await _submitAlipay(tester);
    await tester.tap(find.text('我已支付，确认充值'));
    await tester.pumpAndSettle();
    expect(find.text('重试确认充值'), findsOneWidget);
    expect(find.text('重新打开支付页面'), findsNothing);
    expect(find.text('重新充值'), findsNothing);
    _returnFromBrowser(tester);
    await tester.pumpAndSettle();
    expect(api.posts, hasLength(3));
    api.chargeCode = 200;
    await tester.tap(find.text('重试确认充值'));
    await tester.pumpAndSettle();
    expect(find.text('充值成功'), findsOneWidget);
    expect(api.posts, hasLength(5));
    expect(api.posts[2].data, api.posts[4].data);
    expect(
      api.posts.where(
        (post) => post.path == TuanTuanEndpoints.createAlipayMember,
      ),
      hasLength(1),
    );
  });

  testWidgets('browser failure allows retrying the same order', (tester) async {
    final api = _RechargeApi();
    var opens = 0;
    await _showRecharge(
      tester,
      api,
      AlipayPayService(
        launcher: (_, {mode = LaunchMode.platformDefault}) async => ++opens > 1,
      ),
    );
    await _submitAlipay(tester);
    expect(find.text('无法打开浏览器，请重试'), findsOneWidget);
    await tester.tap(find.text('重新打开支付页面'));
    await tester.pumpAndSettle();
    expect(opens, 2);
    expect(api.posts, hasLength(1));
    expect(find.text('无法打开浏览器，请重试'), findsNothing);
    expect(find.text('充值成功'), findsNothing);
  });

  testWidgets('invalid checkout URL never opens browser or charges', (
    tester,
  ) async {
    final api = _RechargeApi()..redirectUrl = null;
    var opens = 0;
    await _showRecharge(
      tester,
      api,
      AlipayPayService(
        launcher: (_, {mode = LaunchMode.platformDefault}) async {
          opens++;
          return true;
        },
      ),
    );
    await _submitAlipay(tester);
    expect(opens, 0);
    expect(api.posts, hasLength(1));
    expect(find.text('支付宝支付地址无效，请稍后重试'), findsOneWidget);
    expect(find.text('充值成功'), findsNothing);
  });
}
