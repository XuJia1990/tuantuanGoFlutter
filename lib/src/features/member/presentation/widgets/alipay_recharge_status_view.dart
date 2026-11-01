import '../../../../shared/widgets/alipay_payment_status_view.dart';

/// Member recharge keeps its existing labels while sharing the payment layout.
class AlipayRechargeStatusView extends AlipayPaymentStatusView {
  const AlipayRechargeStatusView({
    required super.amount,
    required super.orderId,
    required super.openingBrowser,
    required super.checking,
    required super.paymentConfirmed,
    required super.onConfirm,
    required super.onOpenBrowser,
    required super.onReturn,
    super.message,
    super.key,
  });
}
