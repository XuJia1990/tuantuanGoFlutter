import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_go_flutter/src/app/router/alipay_return_guard.dart';

GoRouter _router({
  required String initialLocation,
  required VoidCallback check,
}) => GoRouter(
  initialLocation: initialLocation,
  onEnter: alipayReturnGuard(checkPendingPayment: check),
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('home')),
    GoRoute(path: '/member', builder: (_, _) => const Text('member')),
    GoRoute(
      path: '/member-recharge',
      builder: (_, _) => const Scaffold(body: TextField()),
    ),
  ],
);

void main() {
  test('recognizes the app return link and associated HTTPS link', () {
    expect(
      AlipayReturnLink.matches(Uri.parse(AlipayReturnLink.appUrl)),
      isTrue,
    );
    expect(
      AlipayReturnLink.matches(
        Uri.parse('https://share.tuantuan-go.com/payment-return'),
      ),
      isTrue,
    );
    for (final link in [
      'tuantuango://other/payment-return',
      'tuantuango://app/other',
      'https://other.example.com/payment-return',
      'https://share.tuantuan-go.com.evil.example.com/payment-return',
      'https://user@share.tuantuan-go.com/payment-return',
      'http://share.tuantuan-go.com/payment-return',
      'https://share.tuantuan-go.com:8443/payment-return',
    ]) {
      expect(AlipayReturnLink.matches(Uri.parse(link)), isFalse, reason: link);
    }
  });

  testWidgets(
    'return link preserves the existing recharge page and its state',
    (tester) async {
      var checks = 0;
      final router = _router(
        initialLocation: '/member-recharge?shopId=1',
        check: () => checks++,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pending order state');
      final fieldState = tester.state(find.byType(TextField));
      router.go('${AlipayReturnLink.appUrl}?status=success&memberOrderId=999');
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/member-recharge',
      );
      expect(tester.state(find.byType(TextField)), same(fieldState));
      expect(find.text('pending order state'), findsOneWidget);
    },
  );

  testWidgets(
    'a cold-start return link opens member page without a payment check',
    (tester) async {
      var checks = 0;
      final router = _router(
        initialLocation: AlipayReturnLink.appUrl,
        check: () => checks++,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('member'), findsOneWidget);
      expect(checks, 0);
    },
  );
}
