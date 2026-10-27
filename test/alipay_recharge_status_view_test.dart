import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_go_flutter/src/app/theme/app_theme.dart';
import 'package:tuantuan_go_flutter/src/features/member/presentation/widgets/alipay_recharge_status_view.dart';

void main() {
  testWidgets(
    'payment actions remain reachable with large text on small screens',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var confirmations = 0;
      for (final size in [const Size(320, 640), const Size(640, 320)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.8),
              ),
              child: Scaffold(
                appBar: AppBar(title: const Text('会员卡充值')),
                body: AlipayRechargeStatusView(
                  amount: '100',
                  orderId: '12345678901234567890',
                  openingBrowser: false,
                  checking: false,
                  paymentConfirmed: false,
                  message: '暂未确认支付结果，到账通知可能有延迟\n已付款请勿重复支付，可稍后重试确认',
                  onConfirm: () => confirmations++,
                  onOpenBrowser: () {},
                  onReturn: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('我已支付，确认充值'));
        await tester.tap(find.text('我已支付，确认充值'));
        await tester.ensureVisible(find.text('返回查看会员余额'));
        expect(tester.takeException(), isNull);
      }
      expect(confirmations, 2);
    },
  );
}
