import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class AlipayRechargeStatusView extends StatelessWidget {
  const AlipayRechargeStatusView({
    required this.amount,
    required this.orderId,
    required this.openingBrowser,
    required this.checking,
    required this.paymentConfirmed,
    required this.onConfirm,
    required this.onOpenBrowser,
    required this.onReturn,
    this.message,
    super.key,
  });

  final String amount;
  final String orderId;
  final bool openingBrowser;
  final bool checking;
  final bool paymentConfirmed;
  final String? message;
  final VoidCallback onConfirm;
  final VoidCallback onOpenBrowser;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final busy = checking || openingBrowser;
    final title = checking
        ? '正在确认充值'
        : paymentConfirmed
        ? '支付成功，待到账'
        : openingBrowser
        ? '正在打开支付页面'
        : '等待支付完成';
    final description = checking
        ? '正在核对支付与到账结果，请稍候'
        : paymentConfirmed
        ? '已确认付款，无需再次支付\n请继续确认本次充值结果'
        : '请在浏览器完成支付宝支付\n支付后回到此页确认充值';
    final buttonText = checking
        ? '确认中...'
        : paymentConfirmed
        ? '重试确认充值'
        : '我已支付，确认充值';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFEEEEF0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x05000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 17,
                            color: Color(0xFF7C828D),
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              '支付宝充值',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7C828D),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3EA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              checking
                                  ? '确认中'
                                  : paymentConfirmed
                                  ? '待到账'
                                  : '待确认',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6FF),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/static/image/zfb.png',
                          width: 46,
                          height: 46,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Semantics(
                        liveRegion: true,
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.8,
                          color: Color(0xFF858B95),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '充值金额',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF858B95),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: '¥ ',
                                    style: TextStyle(fontSize: 22),
                                  ),
                                  TextSpan(text: amount.isEmpty ? '—' : amount),
                                  const TextSpan(
                                    text: '  日元',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF858B95),
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 36,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF262A30),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _RechargeProgress(paymentConfirmed: paymentConfirmed),
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: Color(0xFFF0F1F3)),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '充值订单号',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF979CA5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SelectableText(
                              orderId,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: Color(0xFF6E7580),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (message?.isNotEmpty == true) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7EE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message!,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.7,
                              color: Color(0xFFAA6A2F),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: busy ? null : AppTheme.brandGradient,
                          color: busy ? const Color(0xFFE7E8EB) : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: busy ? null : onConfirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: const Color(0xFF9298A1),
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            child: Text(
                              buttonText,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      if (!paymentConfirmed) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: busy ? null : onOpenBrowser,
                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                          label: Text(openingBrowser ? '正在打开...' : '重新打开支付页面'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF78808D),
                            textStyle: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(fontSize: 13),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: checking ? null : onReturn,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF777E89),
                    textStyle: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(fontSize: 13),
                  ),
                  child: const Text('返回查看会员余额'),
                ),
                const SizedBox(height: 10),
                const Text(
                  '到账情况以充值确认结果为准',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFFACB1B9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RechargeProgress extends StatelessWidget {
  const _RechargeProgress({required this.paymentConfirmed});

  final bool paymentConfirmed;

  @override
  Widget build(BuildContext context) {
    final activeStep = paymentConfirmed ? 2 : 1;
    const labels = ['创建订单', '支付宝支付', '余额到账'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var step = 0; step < labels.length; step++) ...[
          if (step > 0)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.fromLTRB(6, 13, 6, 0),
                color: step <= activeStep
                    ? const Color(0xFFFFD6BC)
                    : const Color(0xFFECEEF1),
              ),
            ),
          Flexible(
            flex: 2,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step <= activeStep
                        ? const Color(0xFFFFF0E5)
                        : const Color(0xFFF4F5F7),
                  ),
                  child: step < activeStep
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppTheme.brand,
                        )
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: step == activeStep
                                ? AppTheme.brand
                                : const Color(0xFFB2B7BF),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[step],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: step == activeStep
                        ? AppTheme.brand
                        : const Color(0xFF979DA6),
                    fontWeight: step == activeStep
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
